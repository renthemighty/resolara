import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_theme.dart';
import '../widgets/web_shell.dart';

/// Clinic dashboard — landing page after login.
///
/// Placeholder content for Milestone A: real data comes from
/// `/api/clinic/me` + `/api/patients` + `/api/sessions/recent` once those
/// endpoints land with the PHP backend work.
class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return WebShell(
      title: 'Dashboard',
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Welcome back',
              style: TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontSize: 28,
                fontWeight: FontWeight.w700,
                color: AppTheme.warmStone,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Your clinic overview',
              style: TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontSize: 14,
                color: AppTheme.sage,
              ),
            ),
            const SizedBox(height: 32),
            Row(
              children: [
                _statCard('Active patients', '—'),
                const SizedBox(width: 16),
                _statCard('Sessions this week', '—'),
                const SizedBox(width: 16),
                _statCard('Practitioners', '—'),
              ],
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () => context.go('/upload'),
              icon: const Icon(Icons.upload_file),
              label: const Text('Upload a report'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.gold,
                foregroundColor: AppTheme.forestTeal,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statCard(String label, String value) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFF122B21),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF1D3A31), width: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontSize: 12,
                color: AppTheme.sage,
                letterSpacing: 0.3,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontSize: 32,
                fontWeight: FontWeight.w700,
                color: AppTheme.warmStone,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
