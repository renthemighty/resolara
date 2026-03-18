import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../app/theme/app_theme.dart';

class AppShell extends StatelessWidget {
  final Widget child;

  const AppShell({super.key, required this.child});

  int _selectedIndex(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    if (location.startsWith('/sessions')) return 1;
    if (location.startsWith('/history')) return 2;
    if (location.startsWith('/settings')) return 3;
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex(context),
        backgroundColor: AppTheme.surface,
        indicatorColor: AppTheme.emerald,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return TextStyle(
            fontSize: 12,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
            color: selected ? AppTheme.gold : AppTheme.warmStone,
            fontFamily: AppTheme.fontFamily,
          );
        }),
        onDestinationSelected: (index) {
          switch (index) {
            case 0:
              context.go('/home');
            case 1:
              context.go('/sessions');
            case 2:
              context.go('/history');
            case 3:
              context.go('/settings');
          }
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.camera_alt_outlined),
            selectedIcon: Icon(Icons.camera_alt),
            label: 'Capture',
          ),
          NavigationDestination(
            icon: Icon(Icons.auto_awesome_outlined),
            selectedIcon: Icon(Icons.auto_awesome),
            label: 'Sessions',
          ),
          NavigationDestination(
            icon: Icon(Icons.folder_outlined),
            selectedIcon: Icon(Icons.folder),
            label: 'Details',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}
