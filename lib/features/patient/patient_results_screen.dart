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
import '../../core/models/share_bundle.dart';
import '../../core/services/notification_service.dart';
import '../../core/storage/app_database.dart';
import '../../core/storage/patient_share_key_storage.dart';

class PatientResultsScreen extends StatefulWidget {
  /// Share code — screen loads everything in the background.
  final String? shareCode;
  /// URL-safe decryption key from the share link's fragment (`#k=...`).
  /// Null when the patient typed the code manually or opened a link with no
  /// fragment — the screen still works, just without personalization
  /// (see the "degraded" state in [_PatientResultsScreenState]).
  final String? shareKey;
  const PatientResultsScreen({super.key, this.shareCode, this.shareKey});

  @override
  State<PatientResultsScreen> createState() => _PatientResultsScreenState();
}

class _PatientResultsScreenState extends State<PatientResultsScreen> {
  final _service = ShareService();

  // Save state
  AppDatabase? _db;
  bool _saved        = false;
  bool _saveLoading  = false;

  // Fetch + decrypt (single combined step — everything in the bundle
  // arrives from one ciphertext blob, there is no more per-section
  // server round trip).
  bool    _loading = false;
  String? _fetchError;
  ShareBundle? _bundle; // null = decryption unavailable (no key, or failed) — degrade gracefully

  // Image
  Uint8List? _imageBytes;
  bool       _imageLoading = false;
  String?    _imageError;
  bool       _imageExpanded = true;

  // Section expansion (data itself comes straight from _bundle — no
  // per-tile loading/retry, it's all decrypted together up front)
  bool _explanationExpanded = false;
  bool _exercisesExpanded   = false;
  bool _medicationsExpanded = false;

  List<FindingExplanation> get _explanations => _bundle?.explanations ?? const [];
  List<Exercise>           get _exercises    => _bundle?.exercises    ?? const [];
  List<Medication>         get _medications  => _bundle?.medications  ?? const [];
  String? get _patientName => _bundle?.patientName;

  @override
  void initState() {
    super.initState();
    if (widget.shareCode != null) {
      _fetchAndDecrypt(widget.shareCode!);
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
        await PatientShareKeyStorage.delete(code);
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
        // The decryption key lives outside the Drift DB (secure storage,
        // never synced/exported with it) so "My Results" keeps working
        // after restart without the key ever touching disk unencrypted.
        if (widget.shareKey != null && widget.shareKey!.isNotEmpty) {
          await PatientShareKeyStorage.save(code, widget.shareKey!);
        }
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

  // ── Fetch + decrypt ─────────────────────────────────────────────────────

  Future<void> _fetchAndDecrypt(String code) async {
    setState(() { _loading = true; _fetchError = null; });
    try {
      final result = await _service.fetchResults(code);
      final bundle = await _service.decryptBundle(result, widget.shareKey);
      if (!mounted) return;
      Analytics.resultsLoaded();
      setState(() {
        _bundle  = bundle;
        _loading = false;
        _explanationExpanded = bundle?.explanations.isNotEmpty ?? false;
        _exercisesExpanded   = bundle?.exercises.isNotEmpty ?? false;
        _medicationsExpanded = bundle?.medications.isNotEmpty ?? false;
      });
      if (result.imageUrl.isNotEmpty) _loadImage(result.imageUrl);
    } on ShareServiceException catch (e) {
      if (!mounted) return;
      setState(() { _loading = false; _fetchError = e.message; });
    } catch (_) {
      if (!mounted) return;
      setState(() { _loading = false; _fetchError = 'Could not load results. Please try again.'; });
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

    if (_loading) {
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
          onRetry: () => _fetchAndDecrypt(widget.shareCode!),
        ),
      );
    }

    final degraded = _bundle == null;
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
            if (degraded) ...[
              const _DegradedNotice(),
              const SizedBox(height: 8),
            ] else if (_bundle != null) ...[
              _DisclosureBanner(text: shareDisclosureText(_bundle!.disclosureVersion)),
              const SizedBox(height: 8),
            ],

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
                  _fetchAndDecrypt(widget.shareCode!);
                } : null,
              ),
            ),

            if (!degraded) ...[
              const SizedBox(height: 8),
              // ── Injury Explanation ─────────────────────────────────────────
              _Tile(
                icon:       Icons.menu_book_outlined,
                title:      'Injury Explanation',
                expanded:   _explanationExpanded,
                hasContent: _explanations.isNotEmpty,
                onToggle: () => setState(() => _explanationExpanded = !_explanationExpanded),
                child: _ExplanationSection(explanations: _explanations),
              ),
              const SizedBox(height: 8),

              // ── Exercise Plan ──────────────────────────────────────────────
              _Tile(
                icon:       Icons.fitness_center_outlined,
                title:      'Exercise Plan',
                expanded:   _exercisesExpanded,
                hasContent: _exercises.isNotEmpty,
                onToggle: () => setState(() => _exercisesExpanded = !_exercisesExpanded),
                child: _ExercisesSection(
                  exercises: _exercises,
                  shareCode: widget.shareCode ?? '',
                ),
              ),
              const SizedBox(height: 8),

              // ── Medications ────────────────────────────────────────────────
              _Tile(
                icon:       Icons.medication_outlined,
                title:      'Medications',
                expanded:   _medicationsExpanded,
                hasContent: _medications.isNotEmpty,
                onToggle: () => setState(() => _medicationsExpanded = !_medicationsExpanded),
                child: _MedicationsSection(
                  medications: _medications,
                  shareCode:   widget.shareCode ?? '',
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Degraded / disclosure banners ────────────────────────────────────────────

class _DegradedNotice extends StatelessWidget {
  const _DegradedNotice();
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color:        AppTheme.sage.withAlpha(25),
          borderRadius: BorderRadius.circular(12),
          border:       Border.all(color: AppTheme.sage.withAlpha(80)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.lock_outline, size: 18, color: AppTheme.sage),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text('Results shared by your practitioner',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                  SizedBox(height: 4),
                  Text(
                    'This code was entered manually, so the personalized '
                    'summary can\'t be unlocked here. Use the QR code or the '
                    'full link your practitioner gave you to see your name, '
                    'explanation, exercises, and medications.',
                    style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
}

class _DisclosureBanner extends StatelessWidget {
  final String text;
  const _DisclosureBanner({required this.text});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color:        AppTheme.gold.withAlpha(18),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.info_outline, size: 16, color: AppTheme.gold),
            const SizedBox(width: 8),
            Expanded(
              child: Text(text,
                  style: const TextStyle(fontSize: 11.5, color: AppTheme.textSecondary)),
            ),
          ],
        ),
      );
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

class _SectionEmpty extends StatelessWidget {
  final String label;
  const _SectionEmpty(this.label);
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.all(20),
        child: Text(label,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
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
  final List<FindingExplanation> explanations;

  const _ExplanationSection({required this.explanations});

  @override
  Widget build(BuildContext context) {
    if (explanations.isEmpty) return const _SectionEmpty('No explanation was shared.');

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
  final List<Exercise> exercises;
  final String         shareCode;

  const _ExercisesSection({
    required this.exercises,
    required this.shareCode,
  });

  @override
  Widget build(BuildContext context) {
    if (exercises.isEmpty) return const _SectionEmpty('No exercises were shared.');

    return ListView.separated(
      shrinkWrap:       true,
      physics:          const NeverScrollableScrollPhysics(),
      padding:          const EdgeInsets.all(16),
      itemCount:        exercises.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder:      (_, i)  => _ExerciseCard(ex: exercises[i], shareCode: shareCode),
    );
  }
}

class _ExerciseCard extends StatefulWidget {
  final Exercise ex;
  final String shareCode;
  const _ExerciseCard({required this.ex, required this.shareCode});

  @override
  State<_ExerciseCard> createState() => _ExerciseCardState();
}

class _ExerciseCardState extends State<_ExerciseCard> {
  bool _reminderActive = false;
  AppDatabase? _db;

  @override
  void initState() {
    super.initState();
    _loadReminderState();
  }

  Future<void> _loadReminderState() async {
    if (widget.shareCode.isEmpty) return;
    _db = await openAppDatabase();
    final existing = await _db!.getReminder(widget.shareCode, widget.ex.name, 'exercise');
    if (mounted && existing != null) setState(() => _reminderActive = true);
  }

  Future<void> _toggleReminder() async {
    if (_reminderActive) {
      await NotificationService.instance.cancelReminder(widget.ex.name, 'exercise');
      await _db?.deleteReminder(widget.shareCode, widget.ex.name, 'exercise');
      if (mounted) setState(() => _reminderActive = false);
    } else {
      final granted = await NotificationService.instance.requestPermission();
      if (!granted || !mounted) return;
      final time = await showTimePicker(context: context, initialTime: const TimeOfDay(hour: 9, minute: 0));
      if (time == null || !mounted) return;
      await NotificationService.instance.scheduleExerciseReminder(
        exerciseId: widget.ex.name, exerciseName: widget.ex.name, time: time);
      _db ??= await openAppDatabase();
      await _db!.insertReminder(PatientRemindersCompanion.insert(
        shareCode: widget.shareCode, itemId: widget.ex.name, itemType: 'exercise',
        itemName: widget.ex.name, reminderHour: time.hour, reminderMinute: time.minute));
      if (mounted) setState(() => _reminderActive = true);
    }
  }

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
    final ex = widget.ex;
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
              if (widget.shareCode.isNotEmpty)
                GestureDetector(
                  onTap: _toggleReminder,
                  child: Icon(
                    _reminderActive ? Icons.notifications_active : Icons.notifications_none,
                    size: 20,
                    color: _reminderActive ? AppTheme.gold : AppTheme.sage,
                  ),
                ),
              if (ex.youtubeQuery.isNotEmpty) ...[
                const SizedBox(width: 12),
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
            ],
          ),
          const SizedBox(height: 8),
          Text(ex.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
              maxLines: 2, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 6),
          Text(ex.description, style: TextStyle(fontSize: 14, color: onSurface),
              maxLines: 4, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 8),
          Row(children: [
            Icon(Icons.repeat_outlined,  size: 13, color: AppTheme.sage),
            const SizedBox(width: 4),
            Flexible(child: Text(ex.repsOrDuration,
                style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                maxLines: 1, overflow: TextOverflow.ellipsis)),
            const SizedBox(width: 12),
            Icon(Icons.schedule_outlined, size: 13, color: AppTheme.sage),
            const SizedBox(width: 4),
            Flexible(child: Text(ex.frequency,
                style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                maxLines: 1, overflow: TextOverflow.ellipsis)),
          ]),
        ],
      ),
    );
  }
}

// ── Medications section ────────────────────────────────────────────────────────

class _MedicationsSection extends StatelessWidget {
  final List<Medication> medications;
  final String           shareCode;

  const _MedicationsSection({
    required this.medications,
    required this.shareCode,
  });

  @override
  Widget build(BuildContext context) {
    if (medications.isEmpty) return const _SectionEmpty('No medications were shared.');

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ListView.separated(
          shrinkWrap:       true,
          physics:          const NeverScrollableScrollPhysics(),
          padding:          const EdgeInsets.all(16),
          itemCount:        medications.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder:      (_, i)  => _MedicationCard(med: medications[i], shareCode: shareCode),
        ),
      ],
    );
  }
}

class _MedicationCard extends StatefulWidget {
  final Medication med;
  final String shareCode;
  const _MedicationCard({required this.med, required this.shareCode});

  @override
  State<_MedicationCard> createState() => _MedicationCardState();
}

class _MedicationCardState extends State<_MedicationCard> {
  bool _reminderActive = false;
  AppDatabase? _db;

  @override
  void initState() {
    super.initState();
    _loadReminderState();
  }

  Future<void> _loadReminderState() async {
    if (widget.shareCode.isEmpty) return;
    _db = await openAppDatabase();
    final existing = await _db!.getReminder(widget.shareCode, widget.med.name, 'medication');
    if (mounted && existing != null) setState(() => _reminderActive = true);
  }

  Future<void> _toggleReminder() async {
    if (_reminderActive) {
      await NotificationService.instance.cancelReminder(widget.med.name, 'medication');
      await _db?.deleteReminder(widget.shareCode, widget.med.name, 'medication');
      if (mounted) setState(() => _reminderActive = false);
    } else {
      final granted = await NotificationService.instance.requestPermission();
      if (!granted || !mounted) return;
      final time = await showTimePicker(context: context, initialTime: const TimeOfDay(hour: 8, minute: 0));
      if (time == null || !mounted) return;
      await NotificationService.instance.scheduleMedicationReminder(
        medicationId: widget.med.name, medicationName: widget.med.name, time: time);
      _db ??= await openAppDatabase();
      await _db!.insertReminder(PatientRemindersCompanion.insert(
        shareCode: widget.shareCode, itemId: widget.med.name, itemType: 'medication',
        itemName: widget.med.name, reminderHour: time.hour, reminderMinute: time.minute));
      if (mounted) setState(() => _reminderActive = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final med = widget.med;
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
              Expanded(child: Text(med.name,
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                  maxLines: 2, overflow: TextOverflow.ellipsis)),
              if (widget.shareCode.isNotEmpty)
                GestureDetector(
                  onTap: _toggleReminder,
                  child: Icon(
                    _reminderActive ? Icons.notifications_active : Icons.notifications_none,
                    size: 20,
                    color: _reminderActive ? AppTheme.gold : AppTheme.sage,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(med.purpose, style: TextStyle(fontSize: 14, color: onSurface),
              maxLines: 4, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 8),
          Row(children: [
            const Icon(Icons.medication_outlined, size: 13, color: AppTheme.sage),
            const SizedBox(width: 4),
            Expanded(child: Text(med.typicalDosing,
                style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                maxLines: 2, overflow: TextOverflow.ellipsis)),
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
