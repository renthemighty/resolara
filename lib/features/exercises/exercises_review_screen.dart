import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../app/theme/app_theme.dart';
import '../../core/api/exercises_service.dart';
import '../../core/models/exercise.dart';
import '../../core/models/extraction_result.dart';

class ExercisesReviewScreen extends StatefulWidget {
  final List<Finding> findings;
  final String patientName;
  final RecoveryPhase phase;

  const ExercisesReviewScreen({
    super.key,
    required this.findings,
    required this.patientName,
    required this.phase,
  });

  @override
  State<ExercisesReviewScreen> createState() => _ExercisesReviewScreenState();
}

class _ExercisesReviewScreenState extends State<ExercisesReviewScreen> {
  final _service       = ExercisesService();
  final _addController = TextEditingController();
  final _addFocus      = FocusNode();

  List<ExerciseEntry> _entries = [];
  bool _loading  = true;
  String? _error;
  bool _restOnly = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _addController.dispose();
    _addFocus.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final exercises =
          await _service.fetchExercises(widget.findings, widget.phase);
      setState(() {
        _restOnly = exercises.isNotEmpty && exercises.every((e) => e.restOnly);
        _entries  = exercises.map((e) => ExerciseEntry(exercise: e)).toList();
        _loading  = false;
      });
    } on ExercisesServiceException catch (e) {
      setState(() { _error = e.message; _loading = false; });
    } catch (e) {
      setState(() {
        _error   = 'Could not load exercise recommendations.';
        _loading = false;
      });
    }
  }

  void _toggle(int i) =>
      setState(() => _entries[i].active = !_entries[i].active);

  void _addExercise() {
    final name = _addController.text.trim();
    if (name.isEmpty) return;
    setState(() {
      _entries.add(ExerciseEntry(
        exercise: Exercise(
          id:             'custom_${DateTime.now().millisecondsSinceEpoch}',
          name:           name,
          description:    '',
          repsOrDuration: '',
          frequency:      '',
          category:       ExerciseCategory.stretch,
          youtubeQuery:   '$name physiotherapy exercise demonstration',
        ),
      ));
      _addController.clear();
    });
    _addFocus.unfocus();
  }

  void _confirm() {
    final active = _entries.where((e) => e.active).toList();
    Navigator.of(context).pop(active);
  }

  Future<void> _openYouTube(String query) async {
    if (query.isEmpty) return;
    final uri = Uri.parse(
        'https://www.youtube.com/results?search_query=${Uri.encodeComponent(query)}');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final activeCount = _entries.where((e) => e.active).length;

    return Scaffold(
      appBar: AppBar(
        title: Text('Exercises · ${widget.phase.label}'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: _loading
          ? const _LoadingView()
          : _error != null
              ? _ErrorView(message: _error!, onRetry: _load)
              : _restOnly
                  ? _RestOnlyView(onContinue: _confirm)
                  : Column(
                      children: [
                        Expanded(
                          child: ListView(
                            padding:
                                const EdgeInsets.fromLTRB(16, 16, 16, 8),
                            children: [
                              Padding(
                                padding: const EdgeInsets.only(
                                    bottom: 16, left: 2),
                                child: Text(
                                  '${widget.phase.label} phase · '
                                  'review and adjust before sharing.',
                                  style: const TextStyle(
                                      fontSize: 13,
                                      color: AppTheme.textSecondary),
                                ),
                              ),
                              ..._entries.asMap().entries.map(
                                    (e) => Padding(
                                      padding: const EdgeInsets.only(
                                          bottom: 12),
                                      child: _ExerciseCard(
                                        entry: e.value,
                                        onToggle: () => _toggle(e.key),
                                        onWatchVideo: () => _openYouTube(
                                            e.value.exercise.youtubeQuery),
                                      ),
                                    ),
                                  ),
                              const SizedBox(height: 4),
                              _AddExerciseRow(
                                controller: _addController,
                                focusNode:  _addFocus,
                                onAdd:      _addExercise,
                              ),
                              const SizedBox(height: 16),
                            ],
                          ),
                        ),
                        _ConfirmBar(
                          activeCount: activeCount,
                          onConfirm:   _confirm,
                        ),
                      ],
                    ),
    );
  }
}

// ── Exercise card ─────────────────────────────────────────────────────────────

class _ExerciseCard extends StatelessWidget {
  final ExerciseEntry entry;
  final VoidCallback onToggle;
  final VoidCallback onWatchVideo;

  const _ExerciseCard({
    required this.entry,
    required this.onToggle,
    required this.onWatchVideo,
  });

  @override
  Widget build(BuildContext context) {
    final isDark   = Theme.of(context).brightness == Brightness.dark;
    final inactive = !entry.active;
    final ex       = entry.exercise;
    final textColor = (isDark ? AppTheme.warmStone : AppTheme.emerald)
        .withAlpha(inactive ? 80 : 255);

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 200),
      opacity: inactive ? 0.5 : 1.0,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: inactive
                ? AppTheme.sage.withAlpha(60)
                : isDark
                    ? const Color(0xFF1E4535)
                    : AppTheme.sage,
            width: 1,
          ),
          color: isDark ? const Color(0xFF122B21) : AppTheme.lightSurface,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header row ───────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _CategoryBadge(category: ex.category, inactive: inactive),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          ex.name,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: textColor,
                            decoration: inactive
                                ? TextDecoration.lineThrough
                                : TextDecoration.none,
                            decorationColor: textColor,
                          ),
                        ),
                        if (ex.description.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            ex.description,
                            style: TextStyle(
                              fontSize: 13,
                              color: AppTheme.textSecondary
                                  .withAlpha(inactive ? 100 : 220),
                              decoration: inactive
                                  ? TextDecoration.lineThrough
                                  : TextDecoration.none,
                              decorationColor: AppTheme.textSecondary,
                            ),
                          ),
                        ],
                        if (ex.repsOrDuration.isNotEmpty ||
                            ex.frequency.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text(
                            [
                              if (ex.repsOrDuration.isNotEmpty)
                                ex.repsOrDuration,
                              if (ex.frequency.isNotEmpty) ex.frequency,
                            ].join(' · '),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: AppTheme.gold
                                  .withAlpha(inactive ? 80 : 200),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  // Toggle button
                  GestureDetector(
                    onTap: onToggle,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: inactive
                            ? AppTheme.sage.withAlpha(30)
                            : AppTheme.error.withAlpha(25),
                        border: Border.all(
                          color: inactive
                              ? AppTheme.sage
                              : AppTheme.error,
                          width: 1.5,
                        ),
                      ),
                      child: Icon(
                        inactive ? Icons.add : Icons.remove,
                        size: 16,
                        color:
                            inactive ? AppTheme.sage : AppTheme.error,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ── YouTube placeholder ──────────────────────────────────
            if (entry.active && ex.youtubeQuery.isNotEmpty) ...[
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                child: _YouTubePlaceholder(
                  category: ex.category,
                  onTap: onWatchVideo,
                ),
              ),
            ] else
              const SizedBox(height: 14),
          ],
        ),
      ),
    );
  }
}

// ── Category badge ────────────────────────────────────────────────────────────

class _CategoryBadge extends StatelessWidget {
  final ExerciseCategory category;
  final bool inactive;

  const _CategoryBadge({required this.category, required this.inactive});

  Color get _color {
    switch (category) {
      case ExerciseCategory.stretch:       return const Color(0xFFB7A46B); // gold
      case ExerciseCategory.mobility:      return const Color(0xFF5BA3DC); // blue
      case ExerciseCategory.strengthening: return const Color(0xFF73978C); // sage
      case ExerciseCategory.rest:          return const Color(0xFF8A8A8A); // grey
    }
  }

  IconData get _icon {
    switch (category) {
      case ExerciseCategory.stretch:       return Icons.self_improvement_outlined;
      case ExerciseCategory.mobility:      return Icons.directions_walk_outlined;
      case ExerciseCategory.strengthening: return Icons.fitness_center_outlined;
      case ExerciseCategory.rest:          return Icons.hotel_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = _color.withAlpha(inactive ? 80 : 255);
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: c.withAlpha(inactive ? 15 : 25),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: c.withAlpha(inactive ? 40 : 80), width: 1),
      ),
      child: Icon(_icon, size: 18, color: c),
    );
  }
}

// ── YouTube placeholder ───────────────────────────────────────────────────────

class _YouTubePlaceholder extends StatelessWidget {
  final ExerciseCategory category;
  final VoidCallback onTap;

  const _YouTubePlaceholder(
      {required this.category, required this.onTap});

  Color get _bgColor {
    switch (category) {
      case ExerciseCategory.stretch:       return const Color(0xFF1A2E1A);
      case ExerciseCategory.mobility:      return const Color(0xFF0D2030);
      case ExerciseCategory.strengthening: return const Color(0xFF1A2420);
      case ExerciseCategory.rest:          return const Color(0xFF1E1E1E);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 90,
        decoration: BoxDecoration(
          color: _bgColor,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
              color: AppTheme.sage.withAlpha(40), width: 1),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: const Color(0xFFFF0000).withAlpha(200),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.play_arrow_rounded,
                  color: Colors.white, size: 22),
            ),
            const SizedBox(width: 12),
            const Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Watch on YouTube',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.warmStone,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Exercise demonstration',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Add exercise row ──────────────────────────────────────────────────────────

class _AddExerciseRow extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final VoidCallback onAdd;

  const _AddExerciseRow({
    required this.controller,
    required this.focusNode,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: controller,
            focusNode: focusNode,
            textCapitalization: TextCapitalization.words,
            style: const TextStyle(fontSize: 14),
            decoration: InputDecoration(
              hintText: 'Add exercise…',
              hintStyle: const TextStyle(
                  fontSize: 14, color: AppTheme.textSecondary),
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AppTheme.sage),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide:
                    const BorderSide(color: AppTheme.sage, width: 1),
              ),
            ),
            onSubmitted: (_) => onAdd(),
          ),
        ),
        const SizedBox(width: 10),
        GestureDetector(
          onTap: onAdd,
          child: Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppTheme.gold.withAlpha(25),
              border: Border.all(color: AppTheme.gold, width: 1.5),
            ),
            child: const Icon(Icons.add, size: 20, color: AppTheme.gold),
          ),
        ),
      ],
    );
  }
}

// ── Rest-only state ───────────────────────────────────────────────────────────

class _RestOnlyView extends StatelessWidget {
  final VoidCallback onContinue;
  const _RestOnlyView({required this.onContinue});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: AppTheme.sage.withAlpha(30),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.hotel_outlined,
                size: 36, color: AppTheme.sage),
          ),
          const SizedBox(height: 24),
          const Text(
            'Rest recommended',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          const Text(
            'Based on the confirmed findings and current recovery phase, '
            'active exercises are not recommended at this stage. '
            'Rest and immobilization are the primary recommendation.',
            textAlign: TextAlign.center,
            style:
                TextStyle(fontSize: 14, color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 32),
          ElevatedButton(
            onPressed: onContinue,
            child: const Text('Continue'),
          ),
        ],
      ),
    );
  }
}

// ── Confirm bar ───────────────────────────────────────────────────────────────

class _ConfirmBar extends StatelessWidget {
  final int activeCount;
  final VoidCallback onConfirm;

  const _ConfirmBar({required this.activeCount, required this.onConfirm});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppTheme.surface,
        border:
            Border(top: BorderSide(color: AppTheme.sage, width: 0.5)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            activeCount == 0
                ? 'No exercises selected'
                : '$activeCount exercise${activeCount == 1 ? '' : 's'} included',
            textAlign: TextAlign.center,
            style: const TextStyle(
                fontSize: 13, color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 10),
          ElevatedButton(
            onPressed: onConfirm,
            child: const Text('Confirm Exercises'),
          ),
        ],
      ),
    );
  }
}

// ── Loading / error ───────────────────────────────────────────────────────────

class _LoadingView extends StatelessWidget {
  const _LoadingView();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(color: AppTheme.gold),
          SizedBox(height: 20),
          Text(
            'Reviewing findings for exercises…',
            style:
                TextStyle(color: AppTheme.textSecondary, fontSize: 14),
          ),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline,
                size: 48, color: AppTheme.error),
            const SizedBox(height: 16),
            Text(message,
                textAlign: TextAlign.center,
                style:
                    const TextStyle(color: AppTheme.textSecondary)),
            const SizedBox(height: 24),
            ElevatedButton(
                onPressed: onRetry, child: const Text('Try Again')),
          ],
        ),
      ),
    );
  }
}
