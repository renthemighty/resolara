import 'dart:io';
import 'dart:typed_data';
import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:go_router/go_router.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart' show Share, XFile;
import 'package:url_launcher/url_launcher.dart';
import '../../app/review_mode.dart';
import '../../app/theme/app_theme.dart';
import 'package:flutter/services.dart';
import '../../core/api/api_client.dart';
import '../../core/api/explanation_service.dart';
import '../../core/api/generation_service.dart';
import '../../core/api/share_service.dart';
import '../../core/api/exercises_service.dart';
import '../../core/api/medications_service.dart';
import '../../core/models/exercise.dart';
import '../../core/models/explanation.dart';
import '../../core/models/extraction_result.dart';
import '../../core/models/generation_job.dart';
import '../../core/models/medication.dart';
import '../../core/storage/app_database.dart';
import '../../core/services/analytics_service.dart';
import '../../core/services/session_service.dart';
import '../../core/storage/secure_file_storage.dart';
import '../../core/utils/image_stamp.dart';
import '../../shared/widgets/loading_overlay.dart';

class ReviewScreen extends StatefulWidget {
  /// Provided when the job has already completed (e.g. opened from history).
  final GenerationJob? job;
  /// Provided when navigating here immediately after submission — ReviewScreen
  /// will poll the job itself and load the image in the background.
  final String? pendingJobId;
  /// Session ID to mark complete once the pending job finishes.
  final String? sessionId;
  final List<Finding> findings;
  final String patientName;
  /// When set, ReviewScreen submits a direct text prompt instead of findings.
  final String? directPrompt;
  /// Token counts from extraction — stored in the session when ReviewScreen
  /// creates the session itself (i.e. when neither job nor pendingJobId is set).
  final int extractionTokensIn;
  final int extractionTokensOut;

  const ReviewScreen({
    super.key,
    this.job,
    this.pendingJobId,
    this.sessionId,
    required this.findings,
    this.patientName = '',
    this.directPrompt,
    this.extractionTokensIn = 0,
    this.extractionTokensOut = 0,
  }) : assert(
          job != null || pendingJobId != null || findings.length > 0,
          'Either job, pendingJobId, or non-empty findings must be provided',
        );

  @override
  State<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends State<ReviewScreen> {
  // ── Job (may be pending when navigated to immediately after submission) ────
  final _genService = GenerationService();
  GenerationJob? _resolvedJob;
  bool _jobPolling = false;
  String? _jobError;
  int _pollGen = 0; // incremented on each poll start; stale continuations bail out
  // Set when ReviewScreen submits the job itself (no pendingJobId passed in).
  String? _localSessionId;
  String? _localPendingJobId;

  // ── Image Visualization section ────────────────────────────────────────────
  _ImageState _imageState = const _ImageLoading();
  bool _imageExpanded = false;
  late List<Finding> _editableFindings;

  // ── Explanation ────────────────────────────────────────────────────────────
  bool _explanationExpanded = false;
  bool _explanationLoading = false;
  List<FindingExplanation> _explanations = [];
  String? _explanationError;
  final _patientExplanationIds = <String>{};

  // ── Exercises ──────────────────────────────────────────────────────────────
  bool _exercisesExpanded = false;
  RecoveryPhase? _exercisePhase;
  bool _exercisesLoading = false;
  List<ExerciseEntry> _exercises = [];
  String? _exercisesError;
  final _patientExerciseIds = <String>{};
  final _exerciseAddController = TextEditingController();
  final _exerciseAddFocus = FocusNode();

  // ── Medications ────────────────────────────────────────────────────────────
  bool _medicationsExpanded = false;
  bool _medicationsLoading = false;
  List<MedicationEntry> _medications = [];
  String? _medicationsError;
  final _medAddController = TextEditingController();
  final _medAddFocus = FocusNode();

  // ── Saving ─────────────────────────────────────────────────────────────────
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _editableFindings = List.of(widget.findings);
    reviewModeNotifier.value = true;
    onDetailsTabTapped = _showDetailsSheet;
    if (widget.pendingJobId != null) {
      _jobPolling = true;
      _pollJob(widget.pendingJobId!);
    } else if (widget.job != null) {
      _resolvedJob = widget.job;
      _loadImage();
    } else {
      // New mode: ReviewScreen submits the job itself and polls in the background.
      // Deferred to post-frame so setState in _submitAndPoll is safe.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _submitAndPoll();
      });
    }
  }

  @override
  void dispose() {
    reviewModeNotifier.value = false;
    onDetailsTabTapped = null;
    _exerciseAddController.dispose();
    _exerciseAddFocus.dispose();
    _medAddController.dispose();
    _medAddFocus.dispose();
    super.dispose();
  }

  // ── Submit + poll (used when ReviewScreen creates the job itself) ──────────

  Future<void> _submitAndPoll() async {
    setState(() { _jobPolling = true; _jobError = null; });
    try {
      final db = await openAppDatabase();
      if (!mounted) return;
      final sessions = SessionService(db);
      final sessionId = await sessions.createSession(
        findings: _editableFindings,
        tokensIn: widget.extractionTokensIn,
        tokensOut: widget.extractionTokensOut,
      );
      if (!mounted) return;
      _localSessionId = sessionId;
      Analytics.generationRequested();
      final jobId = widget.directPrompt != null
          ? await _genService.submitDirectPrompt(widget.directPrompt!, patientName: widget.patientName)
          : await _genService.submitGeneration(_editableFindings, patientName: widget.patientName);
      if (!mounted) return;
      await sessions.setVizJobId(sessionId, jobId);
      if (!mounted) return;
      _localPendingJobId = jobId;
      _pollJob(jobId);
    } on GenerationServiceException catch (e) {
      if (mounted) setState(() {
        _jobPolling = false;
        _jobError = e.message;
        _imageState = _ImageFailed(e.message);
      });
    } catch (e) {
      final msg = '${e.runtimeType}: $e';
      if (mounted) setState(() {
        _jobPolling = false;
        _jobError = msg;
        _imageState = _ImageFailed(msg);
      });
    }
  }

  // ── Job polling (used when navigated to before job completes) ─────────────

  Future<void> _pollJob(String jobId) async {
    final gen = ++_pollGen;
    try {
      await for (final job in _genService.pollJob(jobId)) {
        if (!mounted || gen != _pollGen) return;

        if (job.status == GenerationJobStatus.failed) {
          final msg = job.error ?? 'Generation failed.';
          Analytics.generationFailed(reason: msg);
          setState(() {
            _jobPolling = false;
            _jobError = msg;
            _imageState = _ImageFailed(msg);
          });
          return;
        }

        if (job.status == GenerationJobStatus.completed) {
          Analytics.generationCompleted();
          _resolvedJob = job;
          final sessionId = widget.sessionId ?? _localSessionId;
          if (sessionId != null && job.imageUrl != null) {
            final db = await openAppDatabase();
            if (!mounted || gen != _pollGen) return; // check after first await
            await SessionService(db).completeSession(sessionId, imageUrl: job.imageUrl!);
            if (!mounted || gen != _pollGen) return; // check after second await
          }
          setState(() { _jobPolling = false; _jobError = null; });
          _loadImage();
          return;
        }
      }
    } on GenerationServiceException catch (e) {
      if (mounted && gen == _pollGen) setState(() {
        _jobPolling = false;
        _jobError = e.message;
        _imageState = _ImageFailed(e.message);
      });
    } catch (e) {
      if (mounted && gen == _pollGen) setState(() {
        _jobPolling = false;
        _jobError = 'Generation failed.';
        _imageState = _ImageFailed('Generation failed.');
      });
    } finally {
      // Safety net: _jobPolling must always be cleared even on unexpected exits
      if (mounted && gen == _pollGen && _jobPolling) {
        setState(() => _jobPolling = false);
      }
    }
  }

  // ── Image loading ──────────────────────────────────────────────────────────

  Future<void> _loadImage() async {
    setState(() => _imageState = const _ImageLoading());
    try {
      final imageUrl = _resolvedJob?.imageUrl ?? widget.job?.imageUrl;
      if (imageUrl == null) {
        setState(() => _imageState = const _ImageFailed('No image URL returned from server.'));
        return;
      }
      final response = await ApiClient.instance.dio.get<Uint8List>(
        imageUrl,
        options: Options(responseType: ResponseType.bytes),
      );
      if (response.data == null) {
        setState(() => _imageState = const _ImageFailed('Could not load image.'));
        return;
      }
      if (mounted) {
        setState(() {
          _imageState = _ImageReady(response.data!);
          _imageExpanded = true;
        });
        _loadExplanations();
      }
    } catch (e) {
      if (mounted) setState(() => _imageState = _ImageFailed('Failed to load: $e'));
    }
  }

  // ── Back / exit ────────────────────────────────────────────────────────────

  Future<void> _handleBack() async {
    if (_saving) return;
    final leave = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Leave this review?'),
        content: Text(_jobPolling
            ? 'The visualization is still generating and will not be saved if you leave.'
            : 'The visualization has not been saved yet.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Stay')),
          TextButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Leave')),
        ],
      ),
    );
    if (leave == true && mounted) {
      Navigator.of(context).popUntil((r) => r.settings.name == '/extract' || r.isFirst);
    }
  }

  // ── Regenerate ─────────────────────────────────────────────────────────────

  void _regenerate() => Navigator.of(context).pop(_editableFindings);

  // ── Share ──────────────────────────────────────────────────────────────────

  Future<void> _share() async {
    final state = _imageState;
    if (state is! _ImageReady) return;
    final bytes = widget.patientName.isNotEmpty
        ? await stampPatientLabel(state.bytes, widget.patientName)
        : state.bytes;
    if (!mounted) return;
    final tmp = await getTemporaryDirectory();
    final file = File(p.join(tmp.path, 'resolara_visualization.png'));
    await file.writeAsBytes(bytes);
    final subject = widget.patientName.isNotEmpty
        ? 'Resolara — ${widget.patientName}'
        : 'Resolara Visualization';
    await Share.shareXFiles([XFile(file.path, mimeType: 'image/png')], subject: subject);
  }

  // ── Explanation loading ────────────────────────────────────────────────────

  Future<void> _loadExplanations() async {
    if (_explanationLoading) return;
    setState(() { _explanationLoading = true; _explanationError = null; });
    try {
      final results = await ExplanationService().fetchExplanations(_editableFindings);
      if (!mounted) return;
      setState(() {
        _explanations = results;
        _explanationLoading = false;
        _explanationExpanded = true;
      });
      _loadExercises(RecoveryPhase.acute);
    } on ExplanationServiceException catch (e) {
      if (mounted) setState(() { _explanationError = e.message; _explanationLoading = false; });
    } catch (_) {
      if (mounted) setState(() { _explanationError = 'Could not load explanations.'; _explanationLoading = false; });
    }
  }

  // ── Exercises loading ──────────────────────────────────────────────────────

  Future<void> _loadExercises(RecoveryPhase phase) async {
    setState(() { _exercisePhase = phase; _exercisesLoading = true; _exercisesError = null; _exercises = []; });
    try {
      final results = await ExercisesService().fetchExercises(_editableFindings, phase);
      if (!mounted) return;
      final entries = results.map((e) => ExerciseEntry(exercise: e)).toList();
      setState(() {
        _exercises = entries;
        _exercisesLoading = false;
        _exercisesExpanded = true;
      });
      _loadMedications();
    } on ExercisesServiceException catch (e) {
      if (mounted) setState(() { _exercisesError = e.message; _exercisesLoading = false; });
    } catch (_) {
      if (mounted) setState(() { _exercisesError = 'Could not load exercises.'; _exercisesLoading = false; });
    }
  }

  void _toggleExercise(int i) => setState(() => _exercises[i].active = !_exercises[i].active);

  void _addExercise() {
    final name = _exerciseAddController.text.trim();
    if (name.isEmpty) return;
    setState(() {
      final entry = ExerciseEntry(
        exercise: Exercise(
          id: 'custom_${DateTime.now().millisecondsSinceEpoch}',
          name: name, description: '', repsOrDuration: '', frequency: '',
          category: ExerciseCategory.stretch,
          youtubeQuery: '$name physiotherapy exercise',
        ),
      );
      _exercises.add(entry);
      _patientExerciseIds.add(entry.exercise.id);
      _exerciseAddController.clear();
    });
    _exerciseAddFocus.unfocus();
  }

  Future<void> _openYouTube(String query) async {
    if (query.isEmpty) return;
    final uri = Uri.parse('https://www.youtube.com/results?search_query=${Uri.encodeComponent(query)}');
    if (await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  // ── Medications loading ────────────────────────────────────────────────────

  Future<void> _loadMedications() async {
    if (_medicationsLoading) return;
    setState(() { _medicationsLoading = true; _medicationsError = null; });
    try {
      final meds = await MedicationsService().fetchSuggestions(_editableFindings);
      if (!mounted) return;
      setState(() {
        _medications = meds.map((m) => MedicationEntry(medication: m)).toList();
        _medicationsLoading = false;
        _medicationsExpanded = true;
      });
    } on MedicationsServiceException catch (e) {
      if (mounted) setState(() { _medicationsError = e.message; _medicationsLoading = false; });
    } catch (_) {
      if (mounted) setState(() { _medicationsError = 'Could not load medications.'; _medicationsLoading = false; });
    }
  }

  void _toggleMedication(int i) => setState(() => _medications[i].active = !_medications[i].active);

  void _toggleMedTime(int i, DoseTime t) {
    setState(() {
      if (_medications[i].times.contains(t)) {
        if (_medications[i].times.length > 1) _medications[i].times.remove(t);
      } else {
        _medications[i].times.add(t);
      }
    });
  }

  void _addMedication() {
    final name = _medAddController.text.trim();
    if (name.isEmpty) return;
    setState(() {
      _medications.add(MedicationEntry(
        medication: Medication(
          id: 'custom_${DateTime.now().millisecondsSinceEpoch}',
          name: name, purpose: 'Added by practitioner.',
          typicalDosing: '', aiSuggested: false,
        ),
        active: true,
      ));
      _medAddController.clear();
    });
    _medAddFocus.unfocus();
  }

  void _editExerciseDetails(int i, String reps, String freq) {
    setState(() {
      final entry = _exercises[i];
      entry.customRepsOrDuration = reps.trim().isEmpty ? null : reps.trim();
      entry.customFrequency      = freq.trim().isEmpty ? null : freq.trim();
    });
  }

  Future<void> _showExerciseEditDialog(int i) async {
    final entry   = _exercises[i];
    final repsCtl = TextEditingController(text: entry.effectiveRepsOrDuration);
    final freqCtl = TextEditingController(text: entry.effectiveFrequency);
    final nav     = Navigator.of(context, rootNavigator: true);

    final result = await showDialog<(String, String)>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: Text(entry.exercise.name,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppTheme.warmStone)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: repsCtl,
              autofocus: true,
              style: const TextStyle(fontSize: 13, color: AppTheme.warmStone),
              decoration: InputDecoration(
                labelText: 'Reps / Duration',
                labelStyle: const TextStyle(color: AppTheme.textSecondary),
                hintText: 'e.g. 10 reps, 3 sets',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: freqCtl,
              style: const TextStyle(fontSize: 13, color: AppTheme.warmStone),
              decoration: InputDecoration(
                labelText: 'Frequency',
                labelStyle: const TextStyle(color: AppTheme.textSecondary),
                hintText: 'e.g. 3 times daily',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onSubmitted: (_) => nav.pop((repsCtl.text, freqCtl.text)),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => nav.pop(),
            child: const Text('Cancel', style: TextStyle(color: AppTheme.textSecondary)),
          ),
          TextButton(
            onPressed: () => nav.pop((repsCtl.text, freqCtl.text)),
            child: const Text('Save', style: TextStyle(color: AppTheme.gold)),
          ),
        ],
      ),
    );
    if (!mounted) return;
    if (result != null) _editExerciseDetails(i, result.$1, result.$2);
  }

  void _editMedDosage(int i, String dosage) {
    setState(() => _medications[i].customDosage = dosage.trim().isEmpty ? null : dosage.trim());
  }

  Future<void> _showDosageEditDialog(int i) async {
    final entry = _medications[i];
    final controller = TextEditingController(text: entry.effectiveDosing);
    final nav = Navigator.of(context, rootNavigator: true);
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: Text(entry.medication.name,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppTheme.warmStone)),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: const TextStyle(fontSize: 13, color: AppTheme.warmStone),
          decoration: InputDecoration(
            labelText: 'Dosage',
            labelStyle: const TextStyle(color: AppTheme.textSecondary),
            hintText: 'e.g. 400 mg, twice daily with food',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          ),
          onSubmitted: (_) => nav.pop(controller.text),
        ),
        actions: [
          TextButton(
            onPressed: () => nav.pop(),
            child: const Text('Cancel', style: TextStyle(color: AppTheme.textSecondary)),
          ),
          TextButton(
            onPressed: () => nav.pop(controller.text),
            child: const Text('Save', style: TextStyle(color: AppTheme.gold)),
          ),
        ],
      ),
    );
    if (!mounted) return;
    if (result != null) _editMedDosage(i, result);
  }

  // ── Approve ────────────────────────────────────────────────────────────────

  Future<void> _approve() async {
    final state = _imageState;
    if (state is! _ImageReady) return;
    await _showApproveSheet(state.bytes);
  }

  Future<void> _saveAndDone(Uint8List imageBytes) async {
    Analytics.sessionSaved();
    setState(() => _saving = true);
    try {
      final now = DateTime.now();
      final dir = await getApplicationDocumentsDirectory();
      final savedDir = Directory(p.join(dir.path, 'approved_visualizations'));
      if (!savedDir.existsSync()) savedDir.createSync(recursive: true);
      final filename = 'resolara_${now.millisecondsSinceEpoch}.enc';
      final dest = File(p.join(savedDir.path, filename));
      await SecureFileStorage.writeEncrypted(dest, imageBytes);
      final db = await openAppDatabase();
      final resolvedJob = _resolvedJob ?? widget.job;
      if (resolvedJob == null) {
        if (mounted) {
          setState(() => _saving = false);
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cannot save: visualization data missing.')));
        }
        return;
      }
      final regions = _editableFindings.map((f) => f.bodyRegion).toSet().toList().join(',');
      await db.insertVisualization(VisualizationsCompanion(
        jobId: Value(resolvedJob.jobId),
        imagePath: Value(dest.path),
        createdAt: Value(now.millisecondsSinceEpoch),
        bodyRegions: Value(regions),
        findingCount: Value(_editableFindings.length),
        retainUntil: Value(now.add(const Duration(days: 90)).millisecondsSinceEpoch),
        patientLabel: Value(widget.patientName.isNotEmpty ? widget.patientName : null),
      ));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Saved.')));
      Navigator.of(context).popUntil((r) => r.isFirst);
      context.go('/history');
    } catch (_) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Save failed. Please try again.')));
      }
    }
  }

  // ── Approve sheet ──────────────────────────────────────────────────────────

  Future<void> _showApproveSheet(Uint8List imageBytes) async {
    final explanationCount = _patientExplanationIds.length;
    final exerciseCount = _patientExerciseIds.length;
    final medCount = _medications.where((m) => m.active).length;

    // Create server share record to get a real share code.
    String? shareCode;
    final imageUrl = _resolvedJob?.imageUrl ?? widget.job?.imageUrl;
    if (imageUrl != null) {
      try {
        shareCode = await ShareService().createShare(
          imageUrl: imageUrl,
          findings: _editableFindings
              .map((f) => {'body_region': f.bodyRegion, 'description': f.text, 'layman_term': f.laymanTerm})
              .toList(),
          patientName: widget.patientName.isNotEmpty ? widget.patientName : null,
          explanations: _explanations
              .where((e) => _patientExplanationIds.contains(e.id))
              .map((e) => e.toJson())
              .toList(),
          exercises: _exercises
              .where((e) => _patientExerciseIds.contains(e.exercise.id))
              .map((e) => e.toJson())
              .toList(),
          medications: _medications
              .where((m) => m.active)
              .map((m) => m.toJson())
              .toList(),
        );
        Analytics.shareCreated();
      } catch (_) {
        // Share creation failed — still allow save without a share code.
      }
    }

    if (!mounted) return;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _ApproveSheet(
        shareCode: shareCode,
        patientName: widget.patientName,
        explanationCount: explanationCount,
        exerciseCount: exerciseCount,
        medCount: medCount,
        onSave: () {
          Navigator.of(ctx).pop();
          _saveAndDone(imageBytes);
        },
      ),
    );
  }

  // ── Details sheet (findings editor) ───────────────────────────────────────

  Future<void> _showDetailsSheet() async {
    final updated = await showModalBottomSheet<List<Finding>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _DetailsSheet(findings: _editableFindings),
    );
    if (updated == null || !mounted) return;
    final changed = updated.length != _editableFindings.length ||
        List.generate(updated.length, (i) =>
            updated[i].text != _editableFindings[i].text ||
            updated[i].bodyRegion != _editableFindings[i].bodyRegion).any((c) => c);
    setState(() => _editableFindings = updated);
    if (!changed) return;
    final regen = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Findings updated'),
        content: const Text('Regenerate the visualization with the updated findings?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Keep current')),
          TextButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Regenerate')),
        ],
      ),
    );
    if (regen == true && mounted) Navigator.of(context).pop(updated);
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final imageReady = _imageState is _ImageReady;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) { if (!didPop) _handleBack(); },
      child: Stack(
        children: [
          Scaffold(
            appBar: AppBar(
              title: Text(widget.patientName.isNotEmpty ? widget.patientName : 'Review Visualization'),
              automaticallyImplyLeading: false,
              leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: _handleBack),
            ),
            body: Column(
              children: [
                // ── Sections ─────────────────────────────────────────────
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
                    children: [
                      // ── Image Visualization ──────────────────────────
                      _SectionTile(
                        icon: Icons.image_outlined,
                        title: 'Image Visualization',
                        expanded: _imageExpanded,
                        hasContent: _imageState is _ImageReady,
                        onToggle: () => setState(() => _imageExpanded = !_imageExpanded),
                        child: _ImageAccordionContent(
                          state: _imageState,
                          jobPolling: _jobPolling,
                          onRetry: _jobPolling ? null : _loadImage,
                          onRetryJob: _jobError != null
                              ? () {
                                  final jobId = _localPendingJobId ?? widget.pendingJobId;
                                  if (jobId != null) {
                                    setState(() {
                                      _jobPolling = true;
                                      _jobError = null;
                                      _imageState = const _ImageLoading();
                                    });
                                    _pollJob(jobId);
                                  } else {
                                    _submitAndPoll();
                                  }
                                }
                              : null,
                          onFullscreen: () {
                            final s = _imageState;
                            if (s is! _ImageReady) return;
                            Navigator.of(context).push(PageRouteBuilder(
                              opaque: false,
                              pageBuilder: (_, __, ___) => _FullScreenImage(bytes: s.bytes),
                            ));
                          },
                        ),
                      ),
                      const SizedBox(height: 8),
                      _SectionTile(
                        icon: Icons.article_outlined,
                        title: 'Injury Explanation',
                        expanded: _explanationExpanded,
                        hasContent: _explanations.isNotEmpty,
                        onToggle: () {
                          final opening = !_explanationExpanded;
                          setState(() => _explanationExpanded = opening);
                          if (opening && _explanations.isEmpty && !_explanationLoading) {
                            _loadExplanations();
                          }
                        },
                        child: _ExplanationContent(
                          loading: _explanationLoading,
                          error: _explanationError,
                          explanations: _explanations,
                          patientIds: _patientExplanationIds,
                          onTogglePatient: (id) => setState(() {
                            if (_patientExplanationIds.contains(id)) {
                              _patientExplanationIds.remove(id);
                            } else {
                              _patientExplanationIds.add(id);
                            }
                          }),
                          onRetry: _loadExplanations,
                        ),
                      ),
                      const SizedBox(height: 8),
                      _SectionTile(
                        icon: Icons.fitness_center_outlined,
                        title: 'Exercise Plan',
                        expanded: _exercisesExpanded,
                        hasContent: _exercises.isNotEmpty,
                        onToggle: () => setState(() => _exercisesExpanded = !_exercisesExpanded),
                        child: _ExercisesContent(
                          phase: _exercisePhase,
                          loading: _exercisesLoading,
                          error: _exercisesError,
                          exercises: _exercises,
                          patientIds: _patientExerciseIds,
                          addController: _exerciseAddController,
                          addFocus: _exerciseAddFocus,
                          onSelectPhase: _loadExercises,
                          onToggleExercise: _toggleExercise,
                          onTogglePatient: (id) => setState(() {
                            if (_patientExerciseIds.contains(id)) {
                              _patientExerciseIds.remove(id);
                            } else {
                              _patientExerciseIds.add(id);
                            }
                          }),
                          onWatchVideo: _openYouTube,
                          onEditDetails: _showExerciseEditDialog,
                          onAdd: _addExercise,
                          onRetry: _exercisePhase != null ? () => _loadExercises(_exercisePhase!) : null,
                        ),
                      ),
                      const SizedBox(height: 8),
                      _SectionTile(
                        icon: Icons.medication_outlined,
                        title: 'Medications',
                        expanded: _medicationsExpanded,
                        hasContent: _medications.isNotEmpty,
                        onToggle: () {
                          final opening = !_medicationsExpanded;
                          setState(() => _medicationsExpanded = opening);
                          if (opening && _medications.isEmpty && !_medicationsLoading) {
                            _loadMedications();
                          }
                        },
                        child: _MedicationsContent(
                          loading: _medicationsLoading,
                          error: _medicationsError,
                          medications: _medications,
                          addController: _medAddController,
                          addFocus: _medAddFocus,
                          onToggle: _toggleMedication,
                          onToggleTime: _toggleMedTime,
                          onEditDosage: _showDosageEditDialog,
                          onAdd: _addMedication,
                          onRetry: _loadMedications,
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),

                // ── Action bar ───────────────────────────────────────────
                _ActionBar(
                  imageReady: imageReady,
                  onRegenerate: _regenerate,
                  onShare: imageReady ? _share : null,
                  onApprove: imageReady ? _approve : null,
                ),
              ],
            ),
          ),
          if (_saving) const LoadingOverlay(message: 'Saving…'),
        ],
      ),
    );
  }
}

// ── Image state types ──────────────────────────────────────────────────────────

sealed class _ImageState { const _ImageState(); }
class _ImageLoading extends _ImageState { const _ImageLoading(); }
class _ImageReady extends _ImageState {
  final Uint8List bytes;
  const _ImageReady(this.bytes);
}
class _ImageFailed extends _ImageState {
  final String message;
  const _ImageFailed(this.message);
}

// ── Image accordion content ────────────────────────────────────────────────────

class _ImageAccordionContent extends StatelessWidget {
  final _ImageState state;
  final bool jobPolling;
  final VoidCallback? onRetry;
  final VoidCallback? onRetryJob;
  final VoidCallback onFullscreen;

  const _ImageAccordionContent({
    required this.state,
    required this.jobPolling,
    required this.onRetry,
    required this.onRetryJob,
    required this.onFullscreen,
  });

  @override
  Widget build(BuildContext context) {
    return switch (state) {
      _ImageLoading() => Padding(
          padding: const EdgeInsets.symmetric(vertical: 36),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(color: AppTheme.gold),
                const SizedBox(height: 14),
                Text(
                  jobPolling ? 'Generating visualization…' : 'Loading image…',
                  style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                ),
              ],
            ),
          ),
        ),
      _ImageFailed(message: final msg) => Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 36, color: AppTheme.error),
              const SizedBox(height: 10),
              Text(msg,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
              const SizedBox(height: 14),
              if (onRetryJob != null)
                ElevatedButton(onPressed: onRetryJob, child: const Text('Retry Generation'))
              else if (onRetry != null)
                ElevatedButton(onPressed: onRetry, child: const Text('Retry')),
            ],
          ),
        ),
      _ImageReady(bytes: final bytes) => GestureDetector(
          onTap: onFullscreen,
          child: Container(
            width: double.infinity,
            color: AppTheme.forestTeal,
            child: Hero(
              tag: 'viz_preview',
              child: Image.memory(bytes, fit: BoxFit.fitWidth),
            ),
          ),
        ),
    };
  }
}

// ── Section tile ───────────────────────────────────────────────────────────────

class _SectionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final bool expanded;
  final bool hasContent;
  final VoidCallback onToggle;
  final Widget child;

  const _SectionTile({
    required this.icon,
    required this.title,
    required this.expanded,
    required this.hasContent,
    required this.onToggle,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dimmed = !expanded && !hasContent;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F2920) : AppTheme.lightSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: expanded
              ? AppTheme.gold.withAlpha(120)
              : isDark ? const Color(0xFF1E4535) : AppTheme.sage,
          width: expanded ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          GestureDetector(
            onTap: onToggle,
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Icon(icon,
                      size: 20,
                      color: dimmed
                          ? AppTheme.textSecondary.withAlpha(120)
                          : expanded ? AppTheme.gold : AppTheme.textSecondary),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      title,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: dimmed
                            ? AppTheme.textSecondary.withAlpha(120)
                            : isDark ? AppTheme.warmStone : AppTheme.emerald,
                      ),
                    ),
                  ),
                  Icon(
                    expanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                    size: 20,
                    color: AppTheme.textSecondary,
                  ),
                ],
              ),
            ),
          ),
          if (expanded) ...[
            Divider(height: 1, color: AppTheme.sage.withAlpha(80)),
            child,
          ],
        ],
      ),
    );
  }
}

// ── Explanation content ────────────────────────────────────────────────────────

class _ExplanationContent extends StatelessWidget {
  final bool loading;
  final String? error;
  final List<FindingExplanation> explanations;
  final Set<String> patientIds;
  final void Function(String id) onTogglePatient;
  final VoidCallback onRetry;

  const _ExplanationContent({
    required this.loading,
    required this.error,
    required this.explanations,
    required this.patientIds,
    required this.onTogglePatient,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: AppTheme.gold),
              SizedBox(height: 12),
              Text('Generating explanations…',
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
            ],
          ),
        ),
      );
    }
    if (error != null) {
      return Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Text(error!, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
            const SizedBox(height: 12),
            ElevatedButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          ...explanations.map((e) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _ExplanationCard(
              explanation: e,
              forPatient: patientIds.contains(e.id),
              onTogglePatient: () => onTogglePatient(e.id),
            ),
          )),
        ],
      ),
    );
  }
}

class _ExplanationCard extends StatefulWidget {
  final FindingExplanation explanation;
  final bool forPatient;
  final VoidCallback onTogglePatient;

  const _ExplanationCard({
    required this.explanation,
    required this.forPatient,
    required this.onTogglePatient,
  });

  @override
  State<_ExplanationCard> createState() => _ExplanationCardState();
}

class _ExplanationCardState extends State<_ExplanationCard> {
  bool _expanded = true;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? AppTheme.warmStone : AppTheme.emerald;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? const Color(0xFF1E4535) : AppTheme.sage.withAlpha(180),
        ),
        color: isDark ? const Color(0xFF0A1F1A) : Colors.white,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
              child: Row(
                children: [
                  Expanded(
                    child: Text(widget.explanation.heading,
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: textColor)),
                  ),
                  // Patient include checkbox
                  GestureDetector(
                    onTap: widget.onTogglePatient,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('Patient',
                            style: TextStyle(
                                fontSize: 10,
                                color: widget.forPatient ? AppTheme.gold : AppTheme.textSecondary)),
                        const SizedBox(width: 4),
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 130),
                          width: 18, height: 18,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(4),
                            color: widget.forPatient ? AppTheme.gold : Colors.transparent,
                            border: Border.all(
                              color: widget.forPatient ? AppTheme.gold : AppTheme.sage,
                              width: 1.5,
                            ),
                          ),
                          child: widget.forPatient
                              ? const Icon(Icons.check, size: 12, color: AppTheme.forestTeal)
                              : null,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(_expanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                      size: 18, color: AppTheme.textSecondary),
                ],
              ),
            ),
          ),
          if (_expanded) ...[
            Divider(height: 1, color: AppTheme.sage.withAlpha(60)),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _ExplSection(label: 'What it is', text: widget.explanation.whatItIs, isDark: isDark),
                  const SizedBox(height: 10),
                  _ExplSection(label: 'Why it matters', text: widget.explanation.whyItMatters, isDark: isDark),
                  const SizedBox(height: 10),
                  _ExplSection(label: 'Typical outlook', text: widget.explanation.outlook, isDark: isDark),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ExplSection extends StatelessWidget {
  final String label;
  final String text;
  final bool isDark;
  const _ExplSection({required this.label, required this.text, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label.toUpperCase(),
            style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w700,
                color: AppTheme.gold, letterSpacing: 0.8)),
        const SizedBox(height: 4),
        Text(text,
            style: TextStyle(fontSize: 13, height: 1.5,
                color: isDark ? AppTheme.warmStone.withAlpha(220) : AppTheme.emerald.withAlpha(220))),
      ],
    );
  }
}

// ── Exercises content ──────────────────────────────────────────────────────────

class _ExercisesContent extends StatelessWidget {
  final RecoveryPhase? phase;
  final bool loading;
  final String? error;
  final List<ExerciseEntry> exercises;
  final Set<String> patientIds;
  final TextEditingController addController;
  final FocusNode addFocus;
  final void Function(RecoveryPhase) onSelectPhase;
  final void Function(int) onToggleExercise;
  final void Function(String) onTogglePatient;
  final void Function(String) onWatchVideo;
  final void Function(int) onEditDetails;
  final VoidCallback onAdd;
  final VoidCallback? onRetry;

  const _ExercisesContent({
    required this.phase,
    required this.loading,
    required this.error,
    required this.exercises,
    required this.patientIds,
    required this.addController,
    required this.addFocus,
    required this.onSelectPhase,
    required this.onToggleExercise,
    required this.onTogglePatient,
    required this.onWatchVideo,
    required this.onEditDetails,
    required this.onAdd,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    // Phase not selected yet
    if (phase == null) {
      return Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.only(bottom: 10, left: 2),
              child: Text('Select recovery phase:',
                  style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
            ),
            ...RecoveryPhase.values.map((p) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _PhaseChip(phase: p, onTap: () => onSelectPhase(p)),
            )),
          ],
        ),
      );
    }

    if (loading) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: AppTheme.gold),
              SizedBox(height: 12),
              Text('Loading exercises…',
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
            ],
          ),
        ),
      );
    }

    if (error != null) {
      return Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Text(error!, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
            const SizedBox(height: 12),
            if (onRetry != null) ElevatedButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Phase label + change button
          Row(
            children: [
              Icon(_phaseIcon(phase!), size: 14, color: AppTheme.gold),
              const SizedBox(width: 6),
              Text(phase!.label,
                  style: const TextStyle(fontSize: 12, color: AppTheme.gold, fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 10),
          // 2-col grid
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: 0.82,
            ),
            itemCount: exercises.length,
            itemBuilder: (_, i) => _ExercisePatientCard(
              entry: exercises[i],
              forPatient: patientIds.contains(exercises[i].exercise.id),
              onToggle: () => onToggleExercise(i),
              onTogglePatient: () => onTogglePatient(exercises[i].exercise.id),
              onWatch: () => onWatchVideo(exercises[i].exercise.youtubeQuery),
              onEditDetails: () => onEditDetails(i),
            ),
          ),
          const SizedBox(height: 10),
          // Add row
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: addController,
                  focusNode: addFocus,
                  textCapitalization: TextCapitalization.words,
                  style: const TextStyle(fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'Add exercise…',
                    hintStyle: const TextStyle(fontSize: 13, color: AppTheme.textSecondary),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: AppTheme.sage)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: AppTheme.sage)),
                  ),
                  onSubmitted: (_) => onAdd(),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: onAdd,
                child: Container(
                  width: 38, height: 38,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppTheme.gold.withAlpha(25),
                    border: Border.all(color: AppTheme.gold, width: 1.5),
                  ),
                  child: const Icon(Icons.add, size: 18, color: AppTheme.gold),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  IconData _phaseIcon(RecoveryPhase p) {
    switch (p) {
      case RecoveryPhase.acute: return Icons.healing_outlined;
      case RecoveryPhase.subacute: return Icons.trending_up_outlined;
      case RecoveryPhase.rehabilitation: return Icons.fitness_center_outlined;
    }
  }
}

class _PhaseChip extends StatelessWidget {
  final RecoveryPhase phase;
  final VoidCallback onTap;
  const _PhaseChip({required this.phase, required this.onTap});

  IconData get _icon {
    switch (phase) {
      case RecoveryPhase.acute: return Icons.healing_outlined;
      case RecoveryPhase.subacute: return Icons.trending_up_outlined;
      case RecoveryPhase.rehabilitation: return Icons.fitness_center_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: isDark ? const Color(0xFF1E4535) : AppTheme.sage),
          color: isDark ? const Color(0xFF0A1F1A) : Colors.white,
        ),
        child: Row(
          children: [
            Icon(_icon, size: 18, color: AppTheme.gold),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(phase.label,
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
                          color: isDark ? AppTheme.warmStone : AppTheme.emerald)),
                  Text(phase.subtitle,
                      style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, size: 16, color: AppTheme.textSecondary),
          ],
        ),
      ),
    );
  }
}

class _ExercisePatientCard extends StatelessWidget {
  final ExerciseEntry entry;
  final bool forPatient;
  final VoidCallback onToggle;
  final VoidCallback onTogglePatient;
  final VoidCallback onWatch;
  final VoidCallback onEditDetails;

  const _ExercisePatientCard({
    required this.entry,
    required this.forPatient,
    required this.onToggle,
    required this.onTogglePatient,
    required this.onWatch,
    required this.onEditDetails,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final inactive = !entry.active;
    final ex = entry.exercise;

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 200),
      opacity: inactive ? 0.45 : 1.0,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: inactive
                ? AppTheme.sage.withAlpha(60)
                : isDark ? const Color(0xFF1E4535) : AppTheme.sage,
          ),
          color: isDark ? const Color(0xFF0A1F1A) : Colors.white,
        ),
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Video / icon block
                if (entry.active && ex.youtubeQuery.isNotEmpty)
                  GestureDetector(
                    onTap: onWatch,
                    child: Container(
                      height: 80,
                      decoration: BoxDecoration(
                        color: const Color(0xFF0D2030),
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                      ),
                      child: const Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircleAvatar(
                              radius: 16,
                              backgroundColor: Color(0xCCFF0000),
                              child: Icon(Icons.play_arrow_rounded, color: Colors.white, size: 18),
                            ),
                            SizedBox(height: 4),
                            Text('Watch', style: TextStyle(fontSize: 10, color: AppTheme.warmStone)),
                          ],
                        ),
                      ),
                    ),
                  )
                else
                  Container(
                    height: 56,
                    decoration: BoxDecoration(
                      color: _categoryColor(ex.category).withAlpha(25),
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                    ),
                    child: Center(
                      child: Icon(_categoryIcon(ex.category), size: 22,
                          color: _categoryColor(ex.category).withAlpha(inactive ? 80 : 200)),
                    ),
                  ),
                // Text content
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(8, 8, 8, 6),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          ex.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: isDark ? AppTheme.warmStone : AppTheme.emerald,
                            decoration: inactive ? TextDecoration.lineThrough : TextDecoration.none,
                          ),
                        ),
                        if (entry.effectiveRepsOrDuration.isNotEmpty ||
                            entry.effectiveFrequency.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          GestureDetector(
                            onTap: inactive ? null : onEditDetails,
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      if (entry.effectiveRepsOrDuration.isNotEmpty)
                                        Text(entry.effectiveRepsOrDuration,
                                            style: TextStyle(fontSize: 10,
                                                color: AppTheme.gold.withAlpha(inactive ? 80 : 180))),
                                      if (entry.effectiveFrequency.isNotEmpty)
                                        Text(entry.effectiveFrequency,
                                            style: TextStyle(fontSize: 10,
                                                color: AppTheme.textSecondary.withAlpha(inactive ? 80 : 180))),
                                    ],
                                  ),
                                ),
                                if (!inactive)
                                  Icon(Icons.edit_outlined, size: 10,
                                      color: AppTheme.gold.withAlpha(130)),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
            // Patient checkbox — top left
            Positioned(
              top: 6, left: 6,
              child: GestureDetector(
                onTap: onTogglePatient,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 130),
                  width: 18, height: 18,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(4),
                    color: forPatient ? AppTheme.gold : Colors.black38,
                    border: Border.all(
                        color: forPatient ? AppTheme.gold : Colors.white38, width: 1.5),
                  ),
                  child: forPatient
                      ? const Icon(Icons.check, size: 11, color: AppTheme.forestTeal)
                      : null,
                ),
              ),
            ),
            // +/- toggle — top right
            Positioned(
              top: 6, right: 6,
              child: GestureDetector(
                onTap: onToggle,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: 22, height: 22,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: inactive ? Colors.black26 : AppTheme.error.withAlpha(30),
                    border: Border.all(
                        color: inactive ? Colors.white38 : AppTheme.error, width: 1.5),
                  ),
                  child: Icon(inactive ? Icons.add : Icons.remove, size: 12,
                      color: inactive ? Colors.white70 : AppTheme.error),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _categoryColor(ExerciseCategory c) {
    switch (c) {
      case ExerciseCategory.stretch: return const Color(0xFFB7A46B);
      case ExerciseCategory.mobility: return const Color(0xFF5BA3DC);
      case ExerciseCategory.strengthening: return const Color(0xFF73978C);
      case ExerciseCategory.rest: return const Color(0xFF8A8A8A);
    }
  }

  IconData _categoryIcon(ExerciseCategory c) {
    switch (c) {
      case ExerciseCategory.stretch: return Icons.self_improvement_outlined;
      case ExerciseCategory.mobility: return Icons.directions_walk_outlined;
      case ExerciseCategory.strengthening: return Icons.fitness_center_outlined;
      case ExerciseCategory.rest: return Icons.hotel_outlined;
    }
  }
}

// ── Medications content ────────────────────────────────────────────────────────

class _MedicationsContent extends StatelessWidget {
  final bool loading;
  final String? error;
  final List<MedicationEntry> medications;
  final TextEditingController addController;
  final FocusNode addFocus;
  final void Function(int) onToggle;
  final void Function(int, DoseTime) onToggleTime;
  final void Function(int) onEditDosage;
  final VoidCallback onAdd;
  final VoidCallback onRetry;

  const _MedicationsContent({
    required this.loading,
    required this.error,
    required this.medications,
    required this.addController,
    required this.addFocus,
    required this.onToggle,
    required this.onToggleTime,
    required this.onEditDosage,
    required this.onAdd,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: AppTheme.gold),
              SizedBox(height: 12),
              Text('Loading medications…',
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
            ],
          ),
        ),
      );
    }
    if (error != null) {
      return Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Text(error!, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
            const SizedBox(height: 12),
            ElevatedButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      child: Column(
        children: [
          ...medications.asMap().entries.map((e) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _MedCard(
              entry: e.value,
              onToggle: () => onToggle(e.key),
              onToggleTime: (t) => onToggleTime(e.key, t),
              onEditDosage: () => onEditDosage(e.key),
            ),
          )),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: addController,
                  focusNode: addFocus,
                  textCapitalization: TextCapitalization.words,
                  style: const TextStyle(fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'Add medication…',
                    hintStyle: const TextStyle(fontSize: 13, color: AppTheme.textSecondary),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: AppTheme.sage)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: AppTheme.sage)),
                  ),
                  onSubmitted: (_) => onAdd(),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: onAdd,
                child: Container(
                  width: 38, height: 38,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppTheme.gold.withAlpha(25),
                    border: Border.all(color: AppTheme.gold, width: 1.5),
                  ),
                  child: const Icon(Icons.add, size: 18, color: AppTheme.gold),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MedCard extends StatelessWidget {
  final MedicationEntry entry;
  final VoidCallback onToggle;
  final void Function(DoseTime) onToggleTime;
  final VoidCallback onEditDosage;

  const _MedCard({
    required this.entry,
    required this.onToggle,
    required this.onToggleTime,
    required this.onEditDosage,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final inactive = !entry.active;
    final textColor = (isDark ? AppTheme.warmStone : AppTheme.emerald)
        .withAlpha(inactive ? 80 : 255);

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 200),
      opacity: inactive ? 0.55 : 1.0,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: inactive ? AppTheme.sage.withAlpha(80) : isDark ? const Color(0xFF1E4535) : AppTheme.sage,
          ),
          color: isDark ? const Color(0xFF0A1F1A) : Colors.white,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(entry.medication.name,
                          style: TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w600, color: textColor,
                            decoration: inactive ? TextDecoration.lineThrough : TextDecoration.none,
                            decorationColor: textColor,
                          )),
                      if (entry.medication.purpose.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(entry.medication.purpose,
                            style: TextStyle(fontSize: 12,
                                color: AppTheme.textSecondary.withAlpha(inactive ? 100 : 200),
                                decoration: inactive ? TextDecoration.lineThrough : TextDecoration.none,
                                decorationColor: AppTheme.textSecondary)),
                      ],
                      if (entry.effectiveDosing.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        GestureDetector(
                          onTap: inactive ? null : onEditDosage,
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(entry.effectiveDosing,
                                    style: TextStyle(fontSize: 11,
                                        color: AppTheme.gold.withAlpha(inactive ? 80 : 180),
                                        fontWeight: FontWeight.w500)),
                              ),
                              if (!inactive)
                                Icon(Icons.edit_outlined, size: 11,
                                    color: AppTheme.gold.withAlpha(140)),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                GestureDetector(
                  onTap: onToggle,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    width: 28, height: 28,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: inactive ? AppTheme.sage.withAlpha(30) : AppTheme.error.withAlpha(25),
                      border: Border.all(
                          color: inactive ? AppTheme.sage : AppTheme.error, width: 1.5),
                    ),
                    child: Icon(inactive ? Icons.add : Icons.remove, size: 14,
                        color: inactive ? AppTheme.sage : AppTheme.error),
                  ),
                ),
              ],
            ),
            if (entry.active) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 5,
                runSpacing: 5,
                children: DoseTime.values.map((t) {
                  final on = entry.times.contains(t);
                  return GestureDetector(
                    onTap: () => onToggleTime(t),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 130),
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        color: on ? AppTheme.gold.withAlpha(30) : Colors.transparent,
                        border: Border.all(
                            color: on ? AppTheme.gold : AppTheme.sage.withAlpha(120)),
                      ),
                      child: Text(t.label,
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w500,
                              color: on ? AppTheme.gold : AppTheme.textSecondary)),
                    ),
                  );
                }).toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Action bar ─────────────────────────────────────────────────────────────────

class _ActionBar extends StatelessWidget {
  final bool imageReady;
  final VoidCallback onRegenerate;
  final VoidCallback? onShare;
  final VoidCallback? onApprove;

  const _ActionBar({
    required this.imageReady,
    required this.onRegenerate,
    required this.onShare,
    required this.onApprove,
  });

  @override
  Widget build(BuildContext context) {
    const c = AppTheme.gold;
    return Container(
      decoration: const BoxDecoration(
        color: AppTheme.surface,
        border: Border(top: BorderSide(color: AppTheme.sage, width: 0.5)),
      ),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: onRegenerate,
              icon: const Icon(Icons.refresh, size: 16, color: c),
              label: const Text('Regenerate', style: TextStyle(color: c, fontSize: 13)),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: c, width: 1.5),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: OutlinedButton.icon(
              onPressed: onShare,
              icon: Icon(Icons.share_outlined, size: 16,
                  color: onShare != null ? c : AppTheme.textSecondary),
              label: Text('Share',
                  style: TextStyle(
                      color: onShare != null ? c : AppTheme.textSecondary, fontSize: 13)),
              style: OutlinedButton.styleFrom(
                side: BorderSide(
                    color: onShare != null ? c : AppTheme.textSecondary.withAlpha(80),
                    width: 1.5),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: OutlinedButton.icon(
              onPressed: onApprove,
              icon: Icon(Icons.check_circle_outline, size: 16,
                  color: onApprove != null ? c : AppTheme.textSecondary),
              label: Text('Approve',
                  style: TextStyle(
                      color: onApprove != null ? c : AppTheme.textSecondary, fontSize: 13)),
              style: OutlinedButton.styleFrom(
                side: BorderSide(
                    color: onApprove != null ? c : AppTheme.textSecondary.withAlpha(80),
                    width: 1.5),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Approve sheet ──────────────────────────────────────────────────────────────

class _ApproveSheet extends StatelessWidget {
  final String? shareCode;
  final String patientName;
  final int explanationCount;
  final int exerciseCount;
  final int medCount;
  final VoidCallback onSave;

  const _ApproveSheet({
    required this.shareCode,
    required this.patientName,
    required this.explanationCount,
    required this.exerciseCount,
    required this.medCount,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    final qrData = shareCode != null ? 'https://resolara.ai/results/$shareCode' : null;
    return Container(
      decoration: const BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(24, 20, 24,
          MediaQuery.of(context).viewInsets.bottom + 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40, height: 4,
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
                color: AppTheme.sage.withAlpha(100), borderRadius: BorderRadius.circular(2)),
          ),
          const Text('Share with Patient',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppTheme.warmStone)),
          if (patientName.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(patientName,
                style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
          ],
          const SizedBox(height: 20),
          if (qrData != null) ...[
            // QR code
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: QrImageView(
                data: qrData,
                version: QrVersions.auto,
                size: 180,
                eyeStyle: const QrEyeStyle(
                  eyeShape: QrEyeShape.square,
                  color: Color(0xFF0E3A29),
                ),
                dataModuleStyle: const QrDataModuleStyle(
                  dataModuleShape: QrDataModuleShape.square,
                  color: Color(0xFF0E3A29),
                ),
              ),
            ),
            const SizedBox(height: 14),
            // Share code — large and tappable to copy
            GestureDetector(
              onTap: () {
                Clipboard.setData(ClipboardData(text: shareCode!));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Code copied to clipboard')));
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                decoration: BoxDecoration(
                  color: AppTheme.gold.withAlpha(20),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppTheme.gold.withAlpha(80)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      shareCode!,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 3,
                        color: AppTheme.gold,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Icon(Icons.copy_outlined, size: 16, color: AppTheme.gold),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            const Text('Patient scans the QR or enters this code.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
          ] else ...[
            const Icon(Icons.share_outlined, size: 48, color: AppTheme.textSecondary),
            const SizedBox(height: 8),
            const Text('Sharing unavailable — save to continue.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
          ],
          const SizedBox(height: 12),
          // Summary chips
          Wrap(
            spacing: 8, runSpacing: 6,
            alignment: WrapAlignment.center,
            children: [
              _SummaryChip(icon: Icons.image_outlined, label: 'Image'),
              if (explanationCount > 0)
                _SummaryChip(icon: Icons.article_outlined, label: '$explanationCount explanation${explanationCount == 1 ? '' : 's'}'),
              if (exerciseCount > 0)
                _SummaryChip(icon: Icons.fitness_center_outlined, label: '$exerciseCount exercise${exerciseCount == 1 ? '' : 's'}'),
              if (medCount > 0)
                _SummaryChip(icon: Icons.medication_outlined, label: '$medCount medication${medCount == 1 ? '' : 's'}'),
            ],
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: onSave,
            icon: const Icon(Icons.save_outlined, size: 18),
            label: const Text('Save & Done'),
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(double.infinity, 52),
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _SummaryChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: AppTheme.gold.withAlpha(20),
        border: Border.all(color: AppTheme.gold.withAlpha(80)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: AppTheme.gold),
          const SizedBox(width: 5),
          Text(label, style: const TextStyle(fontSize: 11, color: AppTheme.gold)),
        ],
      ),
    );
  }
}

// ── Full-screen image overlay ──────────────────────────────────────────────────

class _FullScreenImage extends StatelessWidget {
  final Uint8List bytes;
  const _FullScreenImage({required this.bytes});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.of(context).pop(),
      child: Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          child: Stack(
            children: [
              Center(
                child: Hero(
                  tag: 'viz_preview',
                  child: Image.memory(bytes, fit: BoxFit.contain),
                ),
              ),
              Positioned(
                top: 12, right: 16,
                child: GestureDetector(
                  onTap: () => Navigator.of(context).pop(),
                  child: Container(
                    decoration: BoxDecoration(
                        color: Colors.black54, borderRadius: BorderRadius.circular(20)),
                    padding: const EdgeInsets.all(6),
                    child: const Icon(Icons.close, color: Colors.white, size: 22),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Details sheet (findings editor) ───────────────────────────────────────────

class _DetailsSheet extends StatefulWidget {
  final List<Finding> findings;
  const _DetailsSheet({required this.findings});

  @override
  State<_DetailsSheet> createState() => _DetailsSheetState();
}

class _DetailsSheetState extends State<_DetailsSheet> {
  late final List<TextEditingController> _textControllers;
  late final List<TextEditingController> _regionControllers;

  @override
  void initState() {
    super.initState();
    _textControllers = widget.findings.map((f) => TextEditingController(text: f.text)).toList();
    _regionControllers = widget.findings.map((f) => TextEditingController(text: f.bodyRegion)).toList();
  }

  @override
  void dispose() {
    for (final c in _textControllers) { c.dispose(); }
    for (final c in _regionControllers) { c.dispose(); }
    super.dispose();
  }

  List<Finding> _buildUpdated() => List.generate(widget.findings.length, (i) =>
      widget.findings[i].copyWith(
          text: _textControllers[i].text.trim(),
          bodyRegion: _regionControllers[i].text.trim()));

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return DraggableScrollableSheet(
      initialChildSize: 0.92, minChildSize: 0.5, maxChildSize: 0.97,
      expand: false,
      builder: (context, scrollController) => Container(
        decoration: const BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                    color: AppTheme.sage.withAlpha(100), borderRadius: BorderRadius.circular(2)),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: Row(
                children: [
                  const Icon(Icons.list_alt_outlined, size: 20, color: AppTheme.accent),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text('Findings',
                        style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600,
                            color: AppTheme.textPrimary)),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20, color: AppTheme.textSecondary),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: AppTheme.sage),
            Expanded(
              child: ListView.separated(
                controller: scrollController,
                padding: EdgeInsets.fromLTRB(20, 20, 20, bottomInset + 20),
                itemCount: widget.findings.length,
                separatorBuilder: (_, __) => const Divider(height: 32, color: AppTheme.sage),
                itemBuilder: (_, i) => _FindingEditor(
                    number: i + 1,
                    textController: _textControllers[i],
                    regionController: _regionControllers[i]),
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(20, 8, 20, bottomInset + 24),
              child: ElevatedButton.icon(
                onPressed: () => Navigator.of(context).pop(_buildUpdated()),
                icon: const Icon(Icons.check_outlined),
                label: const Text('Save Findings'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FindingEditor extends StatelessWidget {
  final int number;
  final TextEditingController textController;
  final TextEditingController regionController;
  const _FindingEditor({required this.number, required this.textController, required this.regionController});

  @override
  Widget build(BuildContext context) {
    const inputStyle = TextStyle(color: AppTheme.forestTeal, fontSize: 14, fontWeight: FontWeight.w500);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 28, height: 28,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                  color: AppTheme.gold.withAlpha(30),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppTheme.gold.withAlpha(100))),
              child: Text('$number',
                  style: const TextStyle(fontSize: 13, color: AppTheme.gold, fontWeight: FontWeight.w700)),
            ),
            const SizedBox(width: 10),
            const Text('Finding',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
                    color: AppTheme.textSecondary, letterSpacing: 0.4)),
          ],
        ),
        const SizedBox(height: 12),
        const Text('Body region',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
                color: AppTheme.textSecondary, letterSpacing: 0.5)),
        const SizedBox(height: 6),
        TextField(controller: regionController, style: inputStyle,
            decoration: const InputDecoration(
                contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 14))),
        const SizedBox(height: 14),
        const Text('Finding description',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
                color: AppTheme.textSecondary, letterSpacing: 0.5)),
        const SizedBox(height: 6),
        TextField(controller: textController, maxLines: null, minLines: 3,
            style: inputStyle.copyWith(fontWeight: FontWeight.w400),
            decoration: const InputDecoration(
                contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 14))),
      ],
    );
  }
}
