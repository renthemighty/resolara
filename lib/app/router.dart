import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../core/auth/auth_service.dart';
import '../features/activation/activation_screen.dart';
import '../features/capture/capture_screen.dart';
import '../features/history/history_screen.dart';
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
    if (!activated && state.matchedLocation != '/activation') {
      return '/activation';
    }
    return null;
  },
  routes: [
    GoRoute(
      path: '/activation',
      builder: (context, state) => const ActivationScreen(),
    ),
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
  ],
);
