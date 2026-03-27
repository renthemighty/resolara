import 'package:flutter/material.dart';
import '../../app/theme/app_theme.dart';
import '../../core/models/exercise.dart';
import '../../core/models/extraction_result.dart';
import 'exercises_review_screen.dart';

class RecoveryPhaseScreen extends StatelessWidget {
  final List<Finding> findings;
  final String patientName;

  const RecoveryPhaseScreen({
    super.key,
    required this.findings,
    required this.patientName,
  });

  void _select(BuildContext context, RecoveryPhase phase) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => ExercisesReviewScreen(
        findings: findings,
        patientName: patientName,
        phase: phase,
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Exercise Planning'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Where is the patient in their recovery?',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'This determines which exercises are appropriate right now.',
              style: TextStyle(
                fontSize: 13,
                color: AppTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 32),
            ...RecoveryPhase.values.map((phase) => Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: _PhaseCard(
                    phase: phase,
                    onTap: () => _select(context, phase),
                  ),
                )),
          ],
        ),
      ),
    );
  }
}

class _PhaseCard extends StatelessWidget {
  final RecoveryPhase phase;
  final VoidCallback onTap;

  const _PhaseCard({required this.phase, required this.onTap});

  IconData get _icon {
    switch (phase) {
      case RecoveryPhase.acute:          return Icons.healing_outlined;
      case RecoveryPhase.subacute:       return Icons.trending_up_outlined;
      case RecoveryPhase.rehabilitation: return Icons.fitness_center_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark ? const Color(0xFF1E4535) : AppTheme.sage,
            width: 1,
          ),
          color: isDark ? const Color(0xFF122B21) : AppTheme.lightSurface,
        ),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: AppTheme.gold.withAlpha(25),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(_icon, size: 22, color: AppTheme.gold),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    phase.label,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: isDark ? AppTheme.warmStone : AppTheme.emerald,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    phase.subtitle,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right,
                color: AppTheme.textSecondary, size: 20),
          ],
        ),
      ),
    );
  }
}
