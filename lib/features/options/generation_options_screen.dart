import 'package:flutter/material.dart';
import '../../app/theme/app_theme.dart';
import '../../core/models/extraction_result.dart';
import '../explanation/explanation_screen.dart';
import '../exercises/recovery_phase_screen.dart';
import '../medications/medications_review_screen.dart';
import '../review/review_screen.dart';

enum GenerationOption { image, explanation, exercises, meds }

class GenerationOptionsScreen extends StatefulWidget {
  final List<Finding> findings;
  final String patientName;
  final int extractionTokensIn;
  final int extractionTokensOut;
  /// When true only image + explanation are shown (patient mode).
  final bool patientMode;

  const GenerationOptionsScreen({
    super.key,
    required this.findings,
    required this.patientName,
    this.extractionTokensIn  = 0,
    this.extractionTokensOut = 0,
    this.patientMode         = false,
  });

  @override
  State<GenerationOptionsScreen> createState() =>
      _GenerationOptionsScreenState();
}

class _GenerationOptionsScreenState extends State<GenerationOptionsScreen> {
  final _selected = <GenerationOption>{GenerationOption.image};
  bool _running = false;

  List<GenerationOption> get _visibleOptions => widget.patientMode
      ? [GenerationOption.image, GenerationOption.explanation]
      : GenerationOption.values;

  void _toggle(GenerationOption opt) {
    setState(() {
      if (_selected.contains(opt)) {
        _selected.remove(opt);
      } else {
        _selected.add(opt);
      }
    });
  }

  Future<void> _proceed() async {
    if (_selected.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select at least one output.')),
      );
      return;
    }

    setState(() => _running = true);

    // Work through selected options in a fixed order.
    final order = GenerationOption.values
        .where((o) => _selected.contains(o))
        .toList();

    for (final option in order) {
      if (!mounted) return;
      final ok = await _navigateTo(option);
      if (!ok) break; // user cancelled mid-sequence
    }

    if (mounted) setState(() => _running = false);
  }

  Future<bool> _navigateTo(GenerationOption option) async {
    switch (option) {
      case GenerationOption.image:
        await Navigator.of(context).push<void>(
          MaterialPageRoute(
            builder: (_) => ReviewScreen(
              findings:            List.unmodifiable(widget.findings),
              patientName:         widget.patientName,
              extractionTokensIn:  widget.extractionTokensIn,
              extractionTokensOut: widget.extractionTokensOut,
            ),
          ),
        );
        return true; // image screen always continues to next selected option

      case GenerationOption.explanation:
        final result = await Navigator.of(context).push<bool>(
          MaterialPageRoute(
            builder: (_) => ExplanationScreen(findings: widget.findings),
          ),
        );
        return result == true;

      case GenerationOption.exercises:
        final result = await Navigator.of(context).push<dynamic>(
          MaterialPageRoute(
            builder: (_) => RecoveryPhaseScreen(
              findings:    widget.findings,
              patientName: widget.patientName,
            ),
          ),
        );
        return result != null || true;

      case GenerationOption.meds:
        final result = await Navigator.of(context).push<dynamic>(
          MaterialPageRoute(
            builder: (_) =>
                MedicationsReviewScreen(findings: widget.findings),
          ),
        );
        return result != null || true;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('What would you like?'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
              children: [
                const Padding(
                  padding: EdgeInsets.only(bottom: 20, left: 2),
                  child: Text(
                    'Choose what to generate from the confirmed findings.',
                    style: TextStyle(
                        fontSize: 13, color: AppTheme.textSecondary),
                  ),
                ),
                ..._visibleOptions.map((opt) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _OptionCard(
                        option:   opt,
                        selected: _selected.contains(opt),
                        onTap:    () => _toggle(opt),
                      ),
                    )),
              ],
            ),
          ),
          _ProceedBar(
            selectedCount: _selected.length,
            running:       _running,
            onProceed:     _proceed,
          ),
        ],
      ),
    );
  }
}

// ── Option metadata ───────────────────────────────────────────────────────────

extension _OptionMeta on GenerationOption {
  IconData get icon {
    switch (this) {
      case GenerationOption.image:       return Icons.image_outlined;
      case GenerationOption.explanation: return Icons.article_outlined;
      case GenerationOption.exercises:   return Icons.fitness_center_outlined;
      case GenerationOption.meds:        return Icons.medication_outlined;
    }
  }

  String get title {
    switch (this) {
      case GenerationOption.image:       return 'Anatomical Image';
      case GenerationOption.explanation: return 'Injury Explanation';
      case GenerationOption.exercises:   return 'Exercises & Recovery';
      case GenerationOption.meds:        return 'Medications & Reminders';
    }
  }

  String get description {
    switch (this) {
      case GenerationOption.image:
        return 'A 2D visualization showing the affected areas highlighted.';
      case GenerationOption.explanation:
        return 'A plain-language breakdown of each finding and what it means.';
      case GenerationOption.exercises:
        return 'Recommended stretches and exercises where appropriate.';
      case GenerationOption.meds:
        return 'Common prescriptions, routines, and follow-up reminders.';
    }
  }
}

// ── Option card ───────────────────────────────────────────────────────────────

class _OptionCard extends StatelessWidget {
  final GenerationOption option;
  final bool selected;
  final VoidCallback onTap;

  const _OptionCard({
    required this.option,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark      = Theme.of(context).brightness == Brightness.dark;
    final borderColor = selected
        ? AppTheme.gold
        : isDark ? const Color(0xFF1E4535) : AppTheme.sage;
    final bgColor     = selected
        ? AppTheme.gold.withAlpha(isDark ? 22 : 15)
        : Colors.transparent;
    final textColor   = isDark ? AppTheme.warmStone : AppTheme.emerald;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color:        bgColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: borderColor, width: selected ? 1.5 : 1.0),
        ),
        child: Row(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 140),
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: selected
                    ? AppTheme.gold.withAlpha(35)
                    : AppTheme.sage.withAlpha(22),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(option.icon,
                  size: 22,
                  color: selected
                      ? AppTheme.gold
                      : AppTheme.textSecondary),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(option.title,
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: textColor)),
                  const SizedBox(height: 3),
                  Text(option.description,
                      style: const TextStyle(
                          fontSize: 12,
                          color: AppTheme.textSecondary)),
                ],
              ),
            ),
            const SizedBox(width: 12),
            AnimatedContainer(
              duration: const Duration(milliseconds: 140),
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: selected ? AppTheme.gold : Colors.transparent,
                border: Border.all(
                    color: selected ? AppTheme.gold : AppTheme.sage,
                    width: 1.5),
              ),
              child: selected
                  ? const Icon(Icons.check,
                      size: 13, color: AppTheme.forestTeal)
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Proceed bar ───────────────────────────────────────────────────────────────

class _ProceedBar extends StatelessWidget {
  final int selectedCount;
  final bool running;
  final VoidCallback onProceed;

  const _ProceedBar({
    required this.selectedCount,
    required this.running,
    required this.onProceed,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppTheme.surface,
        border: Border(top: BorderSide(color: AppTheme.sage, width: 0.5)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            selectedCount == 0
                ? 'Select at least one output'
                : '$selectedCount output${selectedCount == 1 ? '' : 's'} selected',
            textAlign: TextAlign.center,
            style: const TextStyle(
                fontSize: 13, color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 10),
          ElevatedButton(
            onPressed: (selectedCount > 0 && !running) ? onProceed : null,
            child: running
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: AppTheme.forestTeal),
                  )
                : const Text('Generate'),
          ),
        ],
      ),
    );
  }
}
