import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/app_theme.dart';
import 'web_router.dart';

/// Root widget for the hosted Flutter Web clinic platform.
///
/// Runs at app.resolara.ai as an installable PWA. Uses dark Resolara brand
/// theme (Deep Forest Teal background, Warm Stone text, Antique Gold accent)
/// to match the native feel when installed via Chrome/Edge Window Controls
/// Overlay or Safari "Add to Dock".
class ClinicWebApp extends ConsumerWidget {
  const ClinicWebApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(clinicWebRouterProvider);
    return MaterialApp.router(
      title: 'Resolara Clinic',
      theme: AppTheme.dark,
      routerConfig: router,
      debugShowCheckedModeBanner: false,
    );
  }
}
