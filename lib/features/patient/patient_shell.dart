import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../app/theme/app_theme.dart';

class PatientShell extends StatelessWidget {
  final Widget child;
  const PatientShell({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    final index    = location.startsWith('/patient/results') ? 1 : 0;

    return Scaffold(
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex:   index,
        backgroundColor: AppTheme.surface,
        indicatorColor:  AppTheme.emerald,
        labelTextStyle:  WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return TextStyle(
            fontSize:   12,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
            color:      selected ? AppTheme.gold : AppTheme.warmStone,
            fontFamily: AppTheme.fontFamily,
          );
        }),
        onDestinationSelected: (i) {
          if (i == 0) context.go('/patient');
          if (i == 1) context.go('/patient/results');
        },
        destinations: const [
          NavigationDestination(
            icon:         Icon(Icons.camera_alt_outlined),
            selectedIcon: Icon(Icons.camera_alt),
            label:        'Capture',
          ),
          NavigationDestination(
            icon:         Icon(Icons.folder_outlined),
            selectedIcon: Icon(Icons.folder),
            label:        'My Results',
          ),
        ],
      ),
    );
  }
}
