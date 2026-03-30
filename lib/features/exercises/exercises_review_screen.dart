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
                          child: CustomScrollView(
                            slivers: [
                              // Phase subtitle header
                              SliverToBoxAdapter(
                                child: Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                      14, 14, 14, 10),
                                  child: Text(
                                    '${widget.phase.label} phase · '
                                    'review and adjust before sharing.',
                                    style: const TextStyle(
                                        fontSize: 13,
                                        color: AppTheme.textSecondary),
                                  ),
                                ),
                              ),

                              // 2-column exercise grid
                              SliverPadding(
                                padding: const EdgeInsets.fromLTRB(
                                    12, 12, 12, 8),
                                sliver: SliverGrid(
                                  delegate: SliverChildBuilderDelegate(
                                    (context, index) => _ExerciseCard(
                                      entry: _entries[index],
                                      onToggle: () => _toggle(index),
                                      onWatchVideo: () => _openYouTube(
                                          _entries[index].exercise.youtubeQuery),
                                    ),
                                    childCount: _entries.length,
                                  ),
                                  gridDelegate:
                                      const SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: 2,
                                    mainAxisSpacing: 12,
                                    crossAxisSpacing: 12,
                                    childAspectRatio: 0.85,
                                  ),
                                ),
                              ),

                              // Add exercise row
                              SliverToBoxAdapter(
                                child: Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                      12, 4, 12, 0),
                                  child: _AddExerciseRow(
                                    controller: _addController,
                                    focusNode:  _addFocus,
                                    onAdd:      _addExercise,
                                  ),
                                ),
                              ),

                              // Bottom spacing
                              const SliverToBoxAdapter(
                                child: SizedBox(height: 16),
                              ),
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

// ── Exercise card (grid version) ───────────────────────────────────────────────

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
    final showVideo = entry.active && ex.youtubeQuery.isNotEmpty;

    final textColor = (isDark ? AppTheme.warmStone : AppTheme.emerald)
        .withAlpha(inactive ? 80 : 255);

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 200),
      opacity: inactive ? 0.5 : 1.0,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
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
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top media block
                if (showVideo)
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(13)),
                    child: _YouTubePlaceholder(
                      category: ex.category,
                      height: 96,
                      onTap: onWatchVideo,
                    ),
                  )
                else
                  _CategoryIconBlock(
                    category: ex.category,
                    inactive: inactive,
                  ),

                // Text content
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          ex.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: textColor,
                            decoration: inactive
                                ? TextDecoration.lineThrough
                                : TextDecoration.none,
                            decorationColor: textColor,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            _CategoryBadge(
                                category: ex.category,
                                inactive: inactive,
                                size: 28),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                ex.category.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 10,
                                  color: AppTheme.textSecondary
                                      .withAlpha(inactive ? 100 : 200),
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (ex.repsOrDuration.isNotEmpty ||
                            ex.frequency.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            [
                              if (ex.repsOrDuration.isNotEmpty)
                                ex.repsOrDuration,
                              if (ex.frequency.isNotEmpty) ex.frequency,
                            ].join(' · '),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: AppTheme.gold
                                  .withAlpha(inactive ? 80 : 200),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),

            // Toggle button — top-right overlay
            Positioned(
              top: 6,
              right: 6,
              child: GestureDetector(
                onTap: onToggle,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: inactive
                        ? AppTheme.sage.withAlpha(30)
                        : AppTheme.error.withAlpha(25),
                    border: Border.all(
                      color: inactive ? AppTheme.sage : AppTheme.error,
                      width: 1.5,
                    ),
                  ),
                  child: Icon(
                    inactive ? Icons.add : Icons.remove,
                    size: 14,
                    color: inactive ? AppTheme.sage : AppTheme.error,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Category icon block (shown when no video) ─────────────────────────────────

class _CategoryIconBlock extends StatelessWidget {
  final ExerciseCategory category;
  final bool inactive;

  const _CategoryIconBlock({
    required this.category,
    required this.inactive,
  });

  Color get _bgColor {
    switch (category) {
      case ExerciseCategory.stretch:       return const Color(0xFF1A2E1A);
      case ExerciseCategory.mobility:      return const Color(0xFF0D2030);
      case ExerciseCategory.strengthening: return const Color(0xFF1A2420);
      case ExerciseCategory.rest:          return const Color(0xFF1E1E1E);
    }
  }

  Color get _iconColor {
    switch (category) {
      case ExerciseCategory.stretch:       return const Color(0xFFB7A46B);
      case ExerciseCategory.mobility:      return const Color(0xFF5BA3DC);
      case ExerciseCategory.strengthening: return const Color(0xFF73978C);
      case ExerciseCategory.rest:          return const Color(0xFF8A8A8A);
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
    final c = _iconColor.withAlpha(inactive ? 80 : 255);
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(13)),
      child: Container(
        height: 56,
        color: _bgColor,
        child: Center(
          child: Icon(_icon, size: 24, color: c),
        ),
      ),
    );
  }
}

// ── Category badge ────────────────────────────────────────────────────────────

class _CategoryBadge extends StatelessWidget {
  final ExerciseCategory category;
  final bool inactive;
  final double size;

  const _CategoryBadge({
    required this.category,
    required this.inactive,
    this.size = 36,
  });

  Color get _color {
    switch (category) {
      case ExerciseCategory.stretch:       return const Color(0xFFB7A46B);
      case ExerciseCategory.mobility:      return const Color(0xFF5BA3DC);
      case ExerciseCategory.strengthening: return const Color(0xFF73978C);
      case ExerciseCategory.rest:          return const Color(0xFF8A8A8A);
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
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: c.withAlpha(inactive ? 15 : 25),
        borderRadius: BorderRadius.circular(size * 0.28),
        border: Border.all(color: c.withAlpha(inactive ? 40 : 80), width: 1),
      ),
      child: Icon(_icon, size: size * 0.5, color: c),
    );
  }
}

// ── YouTube placeholder ───────────────────────────────────────────────────────

class _YouTubePlaceholder extends StatelessWidget {
  final ExerciseCategory category;
  final VoidCallback onTap;
  final double height;

  const _YouTubePlaceholder({
    required this.category,
    required this.onTap,
    this.height = 90,
  });

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
        height: height,
        decoration: BoxDecoration(
          color: _bgColor,
          border: Border(
            bottom: BorderSide(color: AppTheme.sage.withAlpha(40), width: 1),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: const Color(0xFFFF0000).withAlpha(200),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.play_arrow_rounded,
                  color: Colors.white, size: 20),
            ),
            const SizedBox(width: 10),
            const Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Watch on YouTube',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.warmStone,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Exercise demo',
                  style: TextStyle(
                    fontSize: 10,
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
