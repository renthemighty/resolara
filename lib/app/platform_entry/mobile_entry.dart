// Mobile entry point — iOS and Android.
// Boots the full mobile app: Firebase, Keychain reset, mobile router (Drift DB,
// camera, OCR, etc.). Selected by conditional import in main.dart for all
// targets except Flutter Web.

import 'dart:io';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../../core/auth/auth_service.dart';
import '../../core/config/app_config.dart';
import '../../core/providers/theme_provider.dart';
import '../../core/services/notification_service.dart';
import '../../firebase_options.dart';
import '../router.dart';
import '../theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Firebase init is non-fatal — app must launch even if it fails
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;
    PlatformDispatcher.instance.onError = (error, stack) {
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
      return true;
    };
  } catch (_) {
    // Firebase unavailable — continue without analytics/crashlytics
  }

  await _clearKeychainOnFreshInstall();
  await AppConfig.loadServerOverride();
  await NotificationService.instance.init();
  runApp(const ProviderScope(child: Resolara()));
}

/// iOS Keychain data survives app deletion. On a fresh install (no marker
/// file present) we wipe secure storage so the user is always logged out.
Future<void> _clearKeychainOnFreshInstall() async {
  try {
    final dir    = await getApplicationSupportDirectory();
    final marker = File('${dir.path}/.launched');
    if (!marker.existsSync()) {
      await AuthService().clearAll();
      await marker.create(recursive: true);
    }
  } catch (_) {
    // non-fatal — proceed normally
  }
}

class Resolara extends ConsumerWidget {
  const Resolara({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider).valueOrNull ?? ThemeMode.system;
    return MaterialApp.router(
      title: 'Resolara',
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeMode,
      routerConfig: appRouter,
      debugShowCheckedModeBanner: false,
    );
  }
}
