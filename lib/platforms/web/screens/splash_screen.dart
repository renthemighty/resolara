import 'package:flutter/material.dart';

import '../../../app/theme/app_theme.dart';

/// Rendered while ClinicAuthNotifier.refresh() is checking /me on boot.
///
/// Keeps the app on this screen until auth state transitions from
/// AuthUnknown to either AuthLoggedIn, AuthLoggedOut, or AuthMfaPending.
/// Matches the pre-Flutter loading screen in web/index.html visually so
/// there is no flash on handoff.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.forestTeal,
      body: Center(
        child: SizedBox(
          width: 32,
          height: 32,
          child: CircularProgressIndicator(
            strokeWidth: 2.5,
            valueColor: AlwaysStoppedAnimation(AppTheme.gold),
          ),
        ),
      ),
    );
  }
}
