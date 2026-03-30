import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../app/theme/app_theme.dart';
import '../../core/auth/auth_service.dart';
import '../../core/services/analytics_service.dart';
import '../../features/capture/capture_screen.dart';
import 'patient_qr_screen.dart';

class PatientHomeScreen extends StatelessWidget {
  const PatientHomeScreen({super.key});

  Future<void> _logout(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sign Out'),
        content: const Text('Sign out of your patient account?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      Analytics.patientLoggedOut();
      await AuthService().clearAll();
      if (context.mounted) {
        // Use the root navigator's router to avoid ShellRoute context issues
        GoRouter.of(context).go('/onboarding');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Resolara'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Sign Out',
            onPressed: () => _logout(context),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Spacer(),

            // Scan QR
            _ActionCard(
              icon:        Icons.qr_code_scanner,
              title:       'Scan QR Code',
              description: 'Receive results your doctor has shared with you.',
              onTap: () {
                Analytics.qrScanStarted();
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const PatientQrScreen()));
              },
            ),

            const SizedBox(height: 16),

            // Take a photo
            _ActionCard(
              icon:        Icons.camera_alt_outlined,
              title:       'Take a Photo',
              description:
                  'Capture a report and generate an image and explanation.',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                    builder: (_) => const CaptureScreen(patientMode: true)),
              ),
            ),

            const Spacer(),
          ],
        ),
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final VoidCallback onTap;

  const _ActionCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isDark ? const Color(0xFF1E4535) : AppTheme.sage,
            width: 1,
          ),
          color: isDark ? const Color(0xFF122B21) : AppTheme.lightSurface,
        ),
        child: Row(
          children: [
            Container(
              width:  56,
              height: 56,
              decoration: BoxDecoration(
                color:        AppTheme.gold.withAlpha(25),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, size: 28, color: AppTheme.gold),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: TextStyle(
                        fontSize:   16,
                        fontWeight: FontWeight.w600,
                        color: isDark ? AppTheme.warmStone : AppTheme.emerald,
                      )),
                  const SizedBox(height: 4),
                  Text(description,
                      style: const TextStyle(
                          fontSize: 13, color: AppTheme.textSecondary)),
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
