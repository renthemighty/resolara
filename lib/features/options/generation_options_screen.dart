import 'package:flutter/material.dart';
import '../../app/theme/app_theme.dart';
import '../../core/models/extraction_result.dart';
import '../generate/generate_screen.dart';

enum GenerationOption { image, explanation, exercises, meds }

class GenerationOptionsScreen extends StatefulWidget {
  final List<Finding> findings;
  final String patientName;
  final int extractionTokensIn;
  final int extractionTokensOut;

  const GenerationOptionsScreen({
    super.key,
    required this.findings,
    required this.patientName,
    this.extractionTokensIn = 0,
    this.extractionTokensOut = 0,
  });

  @override
  State<GenerationOptionsScreen> createState() =>
      _GenerationOptionsScreenState();
}

class _GenerationOptionsScreenState extends State<GenerationOptionsScreen> {
  final _selected = <GenerationOption>{GenerationOption.image};

  void _toggle(GenerationOption opt) {
    setState(() {
      if (_selected.contains(opt)) {
        _selected.remove(opt);
      } else {
        _selected.add(opt);
      }
    });
  }

  void _proceed() {
    if (_selected.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Select at least one output to generate.')),
      );
      return;
    }

    if (_selected.contains(GenerationOption.image)) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => GenerateScreen(
            findings: widget.findings,
            patientName: widget.patientName,
            extractionTokensIn: widget.extractionTokensIn,
            extractionTokensOut: widget.extractionTokensOut,
          ),
        ),
      );
    } else {
      // Non-image options only — screens pending implementation (see Backlog)
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Select Generated Image to continue for now.')),
      );
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
                _OptionCard(
                  selected: _selected.contains(GenerationOption.image),
                  icon: Icons.image_outlined,
                  title: 'Anatomical Image',
                  description:
                      'A 2D visualization showing the affected areas highlighted.',
                  onTap: () => _toggle(GenerationOption.image),
                ),
                const SizedBox(height: 10),
                _OptionCard(
                  selected: _selected.contains(GenerationOption.explanation),
                  icon: Icons.article_outlined,
                  title: 'Injury Explanation',
                  description:
                      'A plain-language breakdown of each finding and what it means.',
                  onTap: () => _toggle(GenerationOption.explanation),
                ),
                const SizedBox(height: 10),
                _OptionCard(
                  selected: _selected.contains(GenerationOption.exercises),
                  icon: Icons.fitness_center_outlined,
                  title: 'Exercises & Recovery',
                  description:
                      'Recommended stretches and exercises where appropriate.',
                  onTap: () => _toggle(GenerationOption.exercises),
                ),
                const SizedBox(height: 10),
                _OptionCard(
                  selected: _selected.contains(GenerationOption.meds),
                  icon: Icons.medication_outlined,
                  title: 'Medications & Reminders',
                  description:
                      'Common prescriptions, routines, and follow-up reminders.',
                  onTap: () => _toggle(GenerationOption.meds),
                ),
              ],
            ),
          ),
          _ProceedBar(
            selectedCount: _selected.length,
            onProceed: _proceed,
          ),
        ],
      ),
    );
  }
}

// ── Option card ───────────────────────────────────────────────────────────────

class _OptionCard extends StatelessWidget {
  final bool selected;
  final IconData icon;
  final String title;
  final String description;
  final VoidCallback onTap;

  const _OptionCard({
    required this.selected,
    required this.icon,
    required this.title,
    required this.description,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final borderColor = selected
        ? AppTheme.gold
        : isDark
            ? const Color(0xFF1E4535)
            : AppTheme.sage;
    final bgColor = selected
        ? AppTheme.gold.withAlpha(isDark ? 22 : 15)
        : Colors.transparent;
    final textColor = isDark ? AppTheme.warmStone : AppTheme.emerald;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(16),
          border:
              Border.all(color: borderColor, width: selected ? 1.5 : 1.0),
        ),
        child: Row(
          children: [
            // Icon badge
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
              child: Icon(
                icon,
                size: 22,
                color: selected ? AppTheme.gold : AppTheme.textSecondary,
              ),
            ),
            const SizedBox(width: 14),
            // Text
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: textColor),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    description,
                    style: const TextStyle(
                        fontSize: 12, color: AppTheme.textSecondary),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            // Checkbox indicator
            AnimatedContainer(
              duration: const Duration(milliseconds: 140),
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: selected ? AppTheme.gold : Colors.transparent,
                border: Border.all(
                  color: selected ? AppTheme.gold : AppTheme.sage,
                  width: 1.5,
                ),
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
  final VoidCallback onProceed;

  const _ProceedBar(
      {required this.selectedCount, required this.onProceed});

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
            selectedCount == 0
                ? 'Select at least one output'
                : '$selectedCount output${selectedCount == 1 ? '' : 's'} selected',
            textAlign: TextAlign.center,
            style: const TextStyle(
                fontSize: 13, color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 10),
          ElevatedButton(
            onPressed: selectedCount > 0 ? onProceed : null,
            child: const Text('Generate'),
          ),
        ],
      ),
    );
  }
}
