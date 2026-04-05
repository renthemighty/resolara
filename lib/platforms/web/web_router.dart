import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'screens/dashboard_screen.dart';
import 'screens/login_screen.dart';
import 'screens/mfa_challenge_screen.dart';
import 'screens/patients_screen.dart';
import 'screens/splash_screen.dart';
import 'screens/upload_screen.dart';
import 'services/clinic_auth_provider.dart';

/// go_router configuration for the clinic web app, Riverpod-driven.
///
/// The router subscribes to [clinicAuthProvider] via a ValueNotifier so it
/// re-evaluates `redirect` whenever the auth state changes (login success,
/// logout, session expired, MFA pending). Result:
///   - AuthUnknown   → hold on /splash until /me finishes
///   - AuthLoggedOut → bounce to /login
///   - AuthMfaPending → bounce to /mfa
///   - AuthLoggedIn  → allow any non-auth route; bounce /login to /
final clinicWebRouterProvider = Provider<GoRouter>((ref) {
  final notifier = ValueNotifier<ClinicAuthState>(ref.read(clinicAuthProvider));
  ref.listen<ClinicAuthState>(clinicAuthProvider, (_, next) {
    notifier.value = next;
  });

  return GoRouter(
    initialLocation: '/splash',
    refreshListenable: notifier,
    redirect: (context, state) {
      final auth = notifier.value;
      final path = state.uri.path;

      if (auth is AuthUnknown) {
        return path == '/splash' ? null : '/splash';
      }
      if (auth is AuthLoggedOut) {
        return path == '/login' ? null : '/login';
      }
      if (auth is AuthMfaPending) {
        return path == '/mfa' ? null : '/mfa';
      }
      if (auth is AuthLoggedIn) {
        if (path == '/login' || path == '/mfa' || path == '/splash') {
          return '/';
        }
        return null;
      }
      return null;
    },
    routes: [
      GoRoute(
        path: '/splash',
        name: 'splash',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: '/login',
        name: 'login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/mfa',
        name: 'mfa',
        builder: (context, state) => const MfaChallengeScreen(),
      ),
      GoRoute(
        path: '/',
        name: 'dashboard',
        builder: (context, state) => const DashboardScreen(),
      ),
      GoRoute(
        path: '/patients',
        name: 'patients',
        builder: (context, state) => const PatientsScreen(),
      ),
      GoRoute(
        path: '/upload',
        name: 'upload',
        builder: (context, state) => const UploadScreen(),
      ),
    ],
  );
});
