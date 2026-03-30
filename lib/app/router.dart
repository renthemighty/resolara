import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../core/auth/auth_service.dart';
import '../core/models/user_role.dart';
import '../features/capture/capture_screen.dart';
import '../features/history/history_screen.dart';
import '../features/onboarding/onboarding_screen.dart';
import '../features/patient/patient_home_screen.dart';
import '../features/patient/patient_saved_results_screen.dart';
import '../features/patient/patient_shell.dart';
import '../features/sessions/sessions_screen.dart';
import '../features/settings/settings_screen.dart';
import 'app_shell.dart';

final _auth = AuthService();

/// Key for the shell's inner navigator — used by AppShell to pop imperative
/// routes when the Capture tab is tapped from anywhere in the flow.
final shellNavigatorKey = GlobalKey<NavigatorState>();

final appRouter = GoRouter(
  initialLocation: '/home',
  redirect: (context, state) async {
    final activated = await _auth.isActivated();
    if (!activated) {
      if (state.matchedLocation == '/onboarding') return null;
      return '/onboarding';
    }
    // Activated — enforce role-based home
    final role = await _auth.getRole();
    final loc  = state.matchedLocation;
    if (role == UserRole.patient) {
      // Patient must stay in /patient subtree
      if (!loc.startsWith('/patient')) return '/patient';
    } else {
      // Practitioner must not land on /patient
      if (loc.startsWith('/patient')) return '/home';
    }
    return null;
  },
  routes: [
    GoRoute(
      path: '/onboarding',
      builder: (context, state) => const OnboardingScreen(),
    ),

    // ── Practitioner shell ─────────────────────────────────────────────────
    ShellRoute(
      navigatorKey: shellNavigatorKey,
      builder: (context, state, child) => AppShell(child: child),
      routes: [
        GoRoute(
          path: '/home',
          builder: (context, state) => const CaptureScreen(),
        ),
        GoRoute(
          path: '/sessions',
          builder: (context, state) => const SessionsScreen(),
        ),
        GoRoute(
          path: '/history',
          builder: (context, state) => const HistoryScreen(),
        ),
        GoRoute(
          path: '/settings',
          builder: (context, state) => const SettingsScreen(),
        ),
      ],
    ),

    // ── Patient shell ──────────────────────────────────────────────────────
    ShellRoute(
      builder: (context, state, child) => PatientShell(child: child),
      routes: [
        GoRoute(
          path: '/patient',
          builder: (context, state) => const PatientHomeScreen(),
        ),
        GoRoute(
          path: '/patient/results',
          builder: (context, state) => const PatientSavedResultsScreen(),
        ),
      ],
    ),
  ],
);
