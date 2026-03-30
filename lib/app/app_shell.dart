import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../app/theme/app_theme.dart';
import '../app/review_mode.dart';
import 'router.dart' show shellNavigatorKey;

class AppShell extends StatelessWidget {
  final Widget child;
  const AppShell({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: reviewModeNotifier,
      builder: (context, inReview, _) {
        final location = GoRouterState.of(context).matchedLocation;

        int selectedIndex;
        if (inReview) {
          if (location.startsWith('/sessions')) selectedIndex = 1;
          else if (location.startsWith('/settings')) selectedIndex = 3;
          else selectedIndex = 0;
        } else {
          if (location.startsWith('/sessions')) selectedIndex = 1;
          else if (location.startsWith('/settings')) selectedIndex = 2;
          else selectedIndex = 0;
        }

        return Scaffold(
          body: child,
          bottomNavigationBar: NavigationBar(
            selectedIndex: selectedIndex,
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
              if (index == 0) {
                // Pop all imperative routes pushed on top of the shell's inner
                // navigator (e.g. ReaderScreen → ExtractScreen → GenerateScreen)
                // before navigating, so Capture always returns to the root screen.
                shellNavigatorKey.currentState?.popUntil((r) => r.isFirst);
                context.go('/home');
                return;
              }
              if (inReview) {
                switch (index) {
                  case 1: context.go('/sessions');
                  case 2: onDetailsTabTapped?.call();
                  case 3: context.go('/settings');
                }
              } else {
                switch (index) {
                  case 1: context.go('/sessions');
                  case 2: context.go('/settings');
                }
              }
            },
            destinations: [
              const NavigationDestination(
                icon: Icon(Icons.home_outlined),
                selectedIcon: Icon(Icons.home),
                label: 'Home',
              ),
              const NavigationDestination(
                icon: Icon(Icons.auto_awesome_outlined),
                selectedIcon: Icon(Icons.auto_awesome),
                label: 'Sessions',
              ),
              if (inReview)
                const NavigationDestination(
                  icon: Icon(Icons.folder_outlined),
                  selectedIcon: Icon(Icons.folder),
                  label: 'Details',
                ),
              const NavigationDestination(
                icon: Icon(Icons.settings_outlined),
                selectedIcon: Icon(Icons.settings),
                label: 'Settings',
              ),
            ],
          ),
        );
      },
    );
  }
}
