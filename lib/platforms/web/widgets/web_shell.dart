import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_theme.dart';
import '../services/clinic_auth_provider.dart';

/// Shared chrome for every logged-in web screen.
///
/// Renders a fixed top bar whose height tracks the Window Controls Overlay
/// CSS env vars (--titlebar-area-*) when the PWA is installed in Chrome/Edge
/// on Win/Mac. When WCO is not active (Safari, iPad, raw browser) the
/// top bar sits at the top of the viewport with a normal height.
///
/// Left side of the nav has the Resolara wordmark; right side has the
/// clinic switcher + user menu. Centre is left empty as a drag region so
/// the OS window can still be moved.
class WebShell extends StatelessWidget {
  const WebShell({
    required this.title,
    required this.body,
    super.key,
  });

  final String title;
  final Widget body;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.forestTeal,
      body: Column(
        children: [
          _TopBar(title: title),
          Expanded(
            child: Row(
              children: [
                const _SideNav(),
                Expanded(child: body),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TopBar extends ConsumerWidget {
  const _TopBar({required this.title});

  final String title;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      height: 56,
      decoration: BoxDecoration(
        color: AppTheme.forestTeal,
        border: Border(
          bottom: BorderSide(color: const Color(0xFF1D3A31), width: 1),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          Text(
            'Resolara',
            style: TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: AppTheme.warmStone,
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(width: 16),
          Container(width: 1, height: 20, color: const Color(0xFF1D3A31)),
          const SizedBox(width: 16),
          Text(
            title,
            style: TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: 14,
              color: AppTheme.sage,
            ),
          ),
          const Spacer(),
          IconButton(
            tooltip: 'Sign out',
            icon: const Icon(Icons.logout, size: 20, color: AppTheme.sage),
            onPressed: () => ref.read(clinicAuthProvider.notifier).logout(),
          ),
        ],
      ),
    );
  }
}

class _SideNav extends StatelessWidget {
  const _SideNav();

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).uri.path;
    return Container(
      width: 220,
      decoration: BoxDecoration(
        color: AppTheme.forestTeal,
        border: Border(
          right: BorderSide(color: const Color(0xFF1D3A31), width: 1),
        ),
      ),
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _navItem(context, Icons.dashboard_outlined, 'Dashboard', '/',
              location == '/'),
          _navItem(context, Icons.upload_file_outlined, 'Upload', '/upload',
              location == '/upload'),
          _navItem(context, Icons.people_outline, 'Patients', '/patients',
              location.startsWith('/patients')),
        ],
      ),
    );
  }

  Widget _navItem(
    BuildContext context,
    IconData icon,
    String label,
    String path,
    bool active,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Material(
        color: active ? const Color(0xFF163A2E) : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () => context.go(path),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: 18,
                  color: active ? AppTheme.gold : AppTheme.sage,
                ),
                const SizedBox(width: 12),
                Text(
                  label,
                  style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: 14,
                    fontWeight: active ? FontWeight.w600 : FontWeight.w500,
                    color: active ? AppTheme.warmStone : AppTheme.sage,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
