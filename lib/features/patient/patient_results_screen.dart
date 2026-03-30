import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../app/theme/app_theme.dart';
import '../../core/api/api_client.dart';
import '../../core/api/share_service.dart';
import '../../core/services/analytics_service.dart';
import '../../core/models/explanation.dart';
import '../../core/models/exercise.dart';
import '../../core/models/medication.dart';
import '../../core/storage/app_database.dart';

class PatientResultsScreen extends StatefulWidget {
  /// Share code — screen loads everything in the background.
  final String? shareCode;
  const PatientResultsScreen({super.key, this.shareCode});

  @override
  State<PatientResultsScreen> createState() => _PatientResultsScreenState();
}

class _PatientResultsScreenState extends State<PatientResultsScreen> {
  final _service = ShareService();

  // Save state
  AppDatabase? _db;
  bool _saved        = false;
  bool _saveLoading  = false;

  // Basic data
  String? _patientName;
  bool    _fetchingBasic = false;
  String? _fetchError;

  // Image
  Uint8List? _imageBytes;
  bool       _imageLoading = false;
  String?    _imageError;
  bool       _imageExpanded = true;

  // Explanations
  List<FindingExplanation> _explanations     = [];
  bool                     _explanationLoading = false;
  String?                  _explanationError;
  bool                     _explanationExpanded = false;

  // Exercises
  List<Exercise> _exercises       = [];
  bool           _exercisesLoading = false;
  String?        _exercisesError;
  bool           _exercisesExpanded = false;
  String         _exercisePhase   = 'acute';

  // Medications
  List<Medication> _medications      = [];
  bool             _medicationsLoading = false;
  String?          _medicationsError;
  bool             _medicationsExpanded = false;

  @override
  void initState() {
    super.initState();
    if (widget.shareCode != null) {
      _fetchBasic(widget.shareCode!);
      _checkSaved(widget.shareCode!);
    }
  }

  Future<void> _checkSaved(String code) async {
    final db = await openAppDatabase();
    if (!mounted) return;
    _db = db;
    final row = await db.getPatientSaved(code);
    if (!mounted) return;
    setState(() => _saved = row != null);
  }

  Future<void> _toggleSave() async {
    final code = widget.shareCode;
    if (code == null || _saveLoading || _db == null) return;
    setState(() => _saveLoading = true);
    try {
      if (_saved) {
        await _db!.deletePatientSaved(code);
        if (!mounted) return;
        setState(() { _saved = false; _saveLoading = false; });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Removed from My Results')));
      } else {
        await _db!.insertPatientSaved(PatientSavedResultsCompanion(
          shareCode:  Value(code.toUpperCase()),
          patientName: Value(_patientName),
          savedAt:    Value(DateTime.now().millisecondsSinceEpoch),
        ));
        if (!mounted) return;
        setState(() { _saved = true; _saveLoading = false; });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Saved to My Results')));
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _saveLoading = false);
    }
  }

  // ── Basic fetch (fast file read) ──────────────────────────────────────────

  Future<void> _fetchBasic(String code) async {
    setState(() { _fetchingBasic = true; _fetchError = null; });
    try {
      final result = await _service.fetchResults(code);
      if (!mounted) return;
      Analytics.resultsLoaded();
      setState(() {
        _patientName   = result.patientName;
        _fetchingBasic = false;
      });
      if (result.imageUrl.isNotEmpty) _loadImage(result.imageUrl);
      _loadExplanations();
    } on ShareServiceException catch (e) {
      if (!mounted) return;
      setState(() { _fetchingBasic = false; _fetchError = e.message; });
    } catch (_) {
      if (!mounted) return;
      setState(() { _fetchingBasic = false; _fetchError = 'Could not load results. Please try again.'; });
    }
  }

  // ── Image ─────────────────────────────────────────────────────────────────

  Future<void> _loadImage(String url) async {
    setState(() { _imageLoading = true; _imageError = null; });
    try {
      final res = await ApiClient.instance.dioNoAuth.get(
        url, options: Options(responseType: ResponseType.bytes));
      if (!mounted) return;
      setState(() {
        _imageBytes  = Uint8List.fromList(res.data as List<int>);
        _imageLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() { _imageLoading = false; _imageError = 'Could not load image.'; });
    }
  }

  // ── Explanations ──────────────────────────────────────────────────────────

  Future<void> _loadExplanations() async {
    final code = widget.shareCode;
    if (code == null || _explanationLoading) return;
    setState(() { _explanationLoading = true; _explanationError = null; });
    try {
      final results = await _service.fetchExplanation(code);
      if (!mounted) return;
      setState(() {
        _explanations       = results;
        _explanationLoading  = false;
        _explanationExpanded = results.isNotEmpty;
      });
      _loadExercises(_exercisePhase);
    } on ShareServiceException catch (e) {
      if (!mounted) return;
      setState(() { _explanationLoading = false; _explanationError = e.message; });
    } catch (_) {
      if (!mounted) return;
      setState(() { _explanationLoading = false; _explanationError = 'Could not load explanations.'; });
    }
  }

  // ── Exercises ─────────────────────────────────────────────────────────────

  Future<void> _loadExercises(String phase) async {
    final code = widget.shareCode;
    if (code == null || _exercisesLoading) return;
    setState(() { _exercisePhase = phase; _exercisesLoading = true; _exercisesError = null; _exercises = []; });
    try {
      final results = await _service.fetchExercises(code, phase);
      if (!mounted) return;
      setState(() {
        _exercises       = results;
        _exercisesLoading = false;
        _exercisesExpanded = results.isNotEmpty;
      });
      _loadMedications();
    } on ShareServiceException catch (e) {
      if (!mounted) return;
      setState(() { _exercisesLoading = false; _exercisesError = e.message; });
    } catch (_) {
      if (!mounted) return;
      setState(() { _exercisesLoading = false; _exercisesError = 'Could not load exercises.'; });
    }
  }

  // ── Medications ───────────────────────────────────────────────────────────

  Future<void> _loadMedications() async {
    final code = widget.shareCode;
    if (code == null || _medicationsLoading) return;
    setState(() { _medicationsLoading = true; _medicationsError = null; });
    try {
      final meds = await _service.fetchMedications(code);
      if (!mounted) return;
      setState(() {
        _medications        = meds;
        _medicationsLoading  = false;
        _medicationsExpanded = meds.isNotEmpty;
      });
    } on ShareServiceException catch (e) {
      if (!mounted) return;
      setState(() { _medicationsLoading = false; _medicationsError = e.message; });
    } catch (_) {
      if (!mounted) return;
      setState(() { _medicationsLoading = false; _medicationsError = 'Could not load medications.'; });
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    // No code provided — shouldn't normally happen via QR flow
    if (widget.shareCode == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('My Results')),
        body: const Center(
          child: Text('No share code provided.',
              style: TextStyle(color: AppTheme.textSecondary)),
        ),
      );
    }

    if (_fetchingBasic) {
      return Scaffold(
        appBar: AppBar(title: const Text('My Results')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_fetchError != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('My Results')),
        body: _ErrorBody(
          message: _fetchError!,
          onRetry: () => _fetchBasic(widget.shareCode!),
        ),
      );
    }

    final title = (_patientName?.isNotEmpty == true) ? _patientName! : 'My Results';

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          if (widget.shareCode != null)
            _saveLoading
                ? const Padding(
                    padding: EdgeInsets.all(14),
                    child: SizedBox(
                      width: 20, height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.gold),
                    ),
                  )
                : IconButton(
                    icon: Icon(
                      _saved ? Icons.bookmark : Icons.bookmark_border,
                      color: _saved ? AppTheme.gold : null,
                    ),
                    tooltip: _saved ? 'Remove from My Results' : 'Save to My Results',
                    onPressed: _toggleSave,
                  ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          children: [
            // ── Image Visualization ────────────────────────────────────────
            _Tile(
              icon:       Icons.image_outlined,
              title:      'Image Visualization',
              expanded:   _imageExpanded,
              hasContent: _imageBytes != null,
              onToggle:   () => setState(() => _imageExpanded = !_imageExpanded),
              child: _ImageSection(
                bytes:    _imageBytes,
                loading:  _imageLoading,
                error:    _imageError,
                onRetry:  _imageError != null ? () {
                  // Re-trigger image fetch from current result — need to re-fetch basic first
                  _fetchBasic(widget.shareCode!);
                } : null,
              ),
            ),
            const SizedBox(height: 8),

            // ── Injury Explanation ─────────────────────────────────────────
            _Tile(
              icon:       Icons.menu_book_outlined,
              title:      'Injury Explanation',
              expanded:   _explanationExpanded,
              hasContent: _explanations.isNotEmpty,
              onToggle: () {
                final opening = !_explanationExpanded;
                setState(() => _explanationExpanded = opening);
                if (opening && _explanations.isEmpty && !_explanationLoading) {
                  _loadExplanations();
                }
              },
              child: _ExplanationSection(
                loading:      _explanationLoading,
                error:        _explanationError,
                explanations: _explanations,
                onRetry:      _loadExplanations,
              ),
            ),
            const SizedBox(height: 8),

            // ── Exercise Plan ──────────────────────────────────────────────
            _Tile(
              icon:       Icons.fitness_center_outlined,
              title:      'Exercise Plan',
              expanded:   _exercisesExpanded,
              hasContent: _exercises.isNotEmpty,
              onToggle: () {
                final opening = !_exercisesExpanded;
                setState(() => _exercisesExpanded = opening);
                if (opening && _exercises.isEmpty && !_exercisesLoading) {
                  _loadExercises(_exercisePhase);
                }
              },
              child: _ExercisesSection(
                loading:   _exercisesLoading,
                error:     _exercisesError,
                exercises: _exercises,
                onRetry:   () => _loadExercises(_exercisePhase),
              ),
            ),
            const SizedBox(height: 8),

            // ── Medications ────────────────────────────────────────────────
            _Tile(
              icon:       Icons.medication_outlined,
              title:      'Medications',
              expanded:   _medicationsExpanded,
              hasContent: _medications.isNotEmpty,
              onToggle: () {
                final opening = !_medicationsExpanded;
                setState(() => _medicationsExpanded = opening);
                if (opening && _medications.isEmpty && !_medicationsLoading) {
                  _loadMedications();
                }
              },
              child: _MedicationsSection(
                loading:     _medicationsLoading,
                error:       _medicationsError,
                medications: _medications,
                onRetry:     _loadMedications,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Accordion tile ─────────────────────────────────────────────────────────────

class _Tile extends StatelessWidget {
  final IconData   icon;
  final String     title;
  final bool       expanded;
  final bool       hasContent;
  final VoidCallback onToggle;
  final Widget     child;

  const _Tile({
    required this.icon,
    required this.title,
    required this.expanded,
    required this.hasContent,
    required this.onToggle,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final isDark       = Theme.of(context).brightness == Brightness.dark;
    final headerColor  = hasContent ? AppTheme.gold : AppTheme.textSecondary.withAlpha(160);
    final surfaceColor = Theme.of(context).colorScheme.surface;

    return Container(
      decoration: BoxDecoration(
        color:        surfaceColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: hasContent
              ? AppTheme.gold.withAlpha(isDark ? 80 : 120)
              : AppTheme.sage.withAlpha(60),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          InkWell(
            onTap:        onToggle,
            borderRadius: BorderRadius.circular(14),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Icon(icon, size: 18, color: headerColor),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(title,
                        style: TextStyle(
                            fontSize:   14,
                            fontWeight: FontWeight.w600,
                            color:      headerColor)),
                  ),
                  Icon(
                    expanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                    size:  18,
                    color: AppTheme.textSecondary.withAlpha(160),
                  ),
                ],
              ),
            ),
          ),
          if (expanded) ...[
            Divider(height: 1, color: AppTheme.sage.withAlpha(60)),
            child,
          ],
        ],
      ),
    );
  }
}

// ── Section loading / error helpers ───────────────────────────────────────────

class _SectionLoading extends StatelessWidget {
  final String label;
  const _SectionLoading(this.label);
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(strokeWidth: 2, color: AppTheme.accent),
            const SizedBox(height: 12),
            Text(label,
                style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
          ],
        ),
      );
}

class _SectionError extends StatelessWidget {
  final String       message;
  final VoidCallback onRetry;
  const _SectionError({required this.message, required this.onRetry});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
            const SizedBox(height: 12),
            OutlinedButton(onPressed: onRetry, child: const Text('Try Again')),
          ],
        ),
      );
}

// ── Image section ──────────────────────────────────────────────────────────────

class _ImageSection extends StatelessWidget {
  final Uint8List?    bytes;
  final bool          loading;
  final String?       error;
  final VoidCallback? onRetry;

  const _ImageSection({
    required this.bytes,
    required this.loading,
    required this.error,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    if (loading) return const _SectionLoading('Loading image…');
    if (error != null) {
      return _SectionError(message: error!, onRetry: onRetry ?? () {});
    }
    if (bytes == null) return const _SectionLoading('Loading image…');
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(14)),
      child: InteractiveViewer(
        child: Image.memory(bytes!, fit: BoxFit.fitWidth),
      ),
    );
  }
}

// ── Explanation section ────────────────────────────────────────────────────────

class _ExplanationSection extends StatelessWidget {
  final bool                     loading;
  final String?                  error;
  final List<FindingExplanation> explanations;
  final VoidCallback             onRetry;

  const _ExplanationSection({
    required this.loading,
    required this.error,
    required this.explanations,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    if (loading)    return const _SectionLoading('Loading explanations…');
    if (error != null) return _SectionError(message: error!, onRetry: onRetry);
    if (explanations.isEmpty) return const _SectionLoading('Loading explanations…');

    return ListView.separated(
      shrinkWrap:       true,
      physics:          const NeverScrollableScrollPhysics(),
      padding:          const EdgeInsets.all(16),
      itemCount:        explanations.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder:      (_, i)  => _ExplanationCard(exp: explanations[i]),
    );
  }
}

class _ExplanationCard extends StatelessWidget {
  final FindingExplanation exp;
  const _ExplanationCard({required this.exp});
  @override
  Widget build(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    return Container(
      padding:    const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color:        Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border:       Border.all(color: AppTheme.sage.withAlpha(60)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(exp.heading,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
          const SizedBox(height: 10),
          _InfoRow('What it is',     exp.whatItIs,     onSurface),
          _InfoRow('Why it matters', exp.whyItMatters, onSurface),
          _InfoRow('Outlook',        exp.outlook,      onSurface),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label, value;
  final Color  color;
  const _InfoRow(this.label, this.value, this.color);
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label.toUpperCase(),
                style: const TextStyle(
                    fontSize: 10, fontWeight: FontWeight.w600,
                    color: AppTheme.sage, letterSpacing: 0.8)),
            const SizedBox(height: 2),
            Text(value, style: TextStyle(fontSize: 14, color: color)),
          ],
        ),
      );
}

// ── Exercises section ──────────────────────────────────────────────────────────

class _ExercisesSection extends StatelessWidget {
  final bool           loading;
  final String?        error;
  final List<Exercise> exercises;
  final VoidCallback   onRetry;

  const _ExercisesSection({
    required this.loading,
    required this.error,
    required this.exercises,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    if (loading)    return const _SectionLoading('Loading exercises…');
    if (error != null) return _SectionError(message: error!, onRetry: onRetry);
    if (exercises.isEmpty) return const _SectionLoading('Loading exercises…');

    return ListView.separated(
      shrinkWrap:       true,
      physics:          const NeverScrollableScrollPhysics(),
      padding:          const EdgeInsets.all(16),
      itemCount:        exercises.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder:      (_, i)  => _ExerciseCard(ex: exercises[i]),
    );
  }
}

class _ExerciseCard extends StatelessWidget {
  final Exercise ex;
  const _ExerciseCard({required this.ex});

  Future<void> _openYouTube(String query) async {
    final uri = Uri.parse(
        'https://www.youtube.com/results?search_query=${Uri.encodeComponent(query)}');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    return Container(
      padding:    const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color:        Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border:       Border.all(color: AppTheme.sage.withAlpha(60)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding:    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color:        AppTheme.emerald.withAlpha(30),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(ex.category.label,
                    style: const TextStyle(
                        fontSize: 11, fontWeight: FontWeight.w600,
                        color: AppTheme.emerald)),
              ),
              const Spacer(),
              if (ex.youtubeQuery.isNotEmpty)
                GestureDetector(
                  onTap: () => _openYouTube(ex.youtubeQuery),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.play_circle_outline, size: 14, color: AppTheme.gold),
                      SizedBox(width: 4),
                      Text('Watch',
                          style: TextStyle(fontSize: 11, color: AppTheme.gold,
                              fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(ex.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
          const SizedBox(height: 6),
          Text(ex.description, style: TextStyle(fontSize: 14, color: onSurface)),
          const SizedBox(height: 8),
          Row(children: [
            Icon(Icons.repeat_outlined,  size: 13, color: AppTheme.sage),
            const SizedBox(width: 4),
            Text(ex.repsOrDuration,
                style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
            const SizedBox(width: 12),
            Icon(Icons.schedule_outlined, size: 13, color: AppTheme.sage),
            const SizedBox(width: 4),
            Text(ex.frequency,
                style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
          ]),
        ],
      ),
    );
  }
}

// ── Medications section ────────────────────────────────────────────────────────

class _MedicationsSection extends StatelessWidget {
  final bool             loading;
  final String?          error;
  final List<Medication> medications;
  final VoidCallback     onRetry;

  const _MedicationsSection({
    required this.loading,
    required this.error,
    required this.medications,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    if (loading)      return const _SectionLoading('Loading medications…');
    if (error != null) return _SectionError(message: error!, onRetry: onRetry);
    if (medications.isEmpty) return const _SectionLoading('Loading medications…');

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ListView.separated(
          shrinkWrap:       true,
          physics:          const NeverScrollableScrollPhysics(),
          padding:          const EdgeInsets.all(16),
          itemCount:        medications.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder:      (_, i)  => _MedicationCard(med: medications[i]),
        ),
      ],
    );
  }
}

class _MedicationCard extends StatelessWidget {
  final Medication med;
  const _MedicationCard({required this.med});
  @override
  Widget build(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    return Container(
      padding:    const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color:        Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border:       Border.all(color: AppTheme.sage.withAlpha(60)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(med.name,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
          const SizedBox(height: 6),
          Text(med.purpose, style: TextStyle(fontSize: 14, color: onSurface)),
          const SizedBox(height: 8),
          Row(children: [
            const Icon(Icons.medication_outlined, size: 13, color: AppTheme.sage),
            const SizedBox(width: 4),
            Text(med.typicalDosing,
                style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
          ]),
        ],
      ),
    );
  }
}

// ── Error body ─────────────────────────────────────────────────────────────────

class _ErrorBody extends StatelessWidget {
  final String       message;
  final VoidCallback onRetry;
  const _ErrorBody({required this.message, required this.onRetry});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(Icons.error_outline, size: 48, color: AppTheme.error),
            const SizedBox(height: 16),
            Text(message,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppTheme.textSecondary)),
            const SizedBox(height: 24),
            ElevatedButton(onPressed: onRetry, child: const Text('Try Again')),
          ],
        ),
      );
}
