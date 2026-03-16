import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../app/theme/app_theme.dart';
import '../../../core/auth/auth_service.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          ListTile(
            title: const Text('Sign Out'),
            leading: const Icon(Icons.logout, color: AppTheme.error),
            onTap: () async {
              await AuthService().clearAll();
              if (context.mounted) context.go('/activation');
            },
          ),
        ],
      ),
    );
  }
}
