import 'package:go_router/go_router.dart';

import 'screens/dashboard_screen.dart';
import 'screens/login_screen.dart';
import 'screens/upload_screen.dart';

/// go_router configuration for the clinic web app.
///
/// URL structure (all client-side routes, served by .htaccess SPA fallback):
/// - `/login`          — sign in with email + password + optional TOTP
/// - `/`               — dashboard (patient count, recent sessions)
/// - `/patients`       — patient list
/// - `/upload`         — file drop / picker (also landing for OS "open with")
/// - `/sessions/:id`   — review a single clinical visualization
///
/// For Milestone A the router is deliberately thin. Auth gating, clinic
/// context, and session refresh will land with the real auth service.
final clinicWebRouter = GoRouter(
  initialLocation: '/login',
  routes: [
    GoRoute(
      path: '/login',
      name: 'login',
      builder: (context, state) => const LoginScreen(),
    ),
    GoRoute(
      path: '/',
      name: 'dashboard',
      builder: (context, state) => const DashboardScreen(),
    ),
    GoRoute(
      path: '/upload',
      name: 'upload',
      builder: (context, state) => const UploadScreen(),
    ),
  ],
);
