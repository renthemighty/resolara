import 'dart:io';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:path_provider/path_provider.dart';
import '../../../app/theme/app_theme.dart';
import '../../../core/auth/auth_service.dart';
import '../../../core/storage/app_database.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  Future<void> _resetEverything(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reset Everything?'),
        content: const Text(
          'This will sign you out, delete all saved visualizations and cached data, '
          'and return the app to its initial state. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppTheme.error),
            child: const Text('Reset'),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    // 1. Clear auth tokens and activation code
    await AuthService().clearAll();

    // 2. Delete all saved visualization image files
    try {
      final dir = await getApplicationDocumentsDirectory();
      final vizDir = Directory('${dir.path}/approved_visualizations');
      if (await vizDir.exists()) await vizDir.delete(recursive: true);
    } catch (_) {}

    // 3. Wipe the database
    try {
      final db = await openAppDatabase();
      await db.delete(db.visualizations).go();
    } catch (_) {}

    if (context.mounted) context.go('/activation');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          ListTile(
            title: const Text('Sign Out'),
            leading: const Icon(Icons.logout, color: AppTheme.textSecondary),
            onTap: () async {
              await AuthService().clearAll();
              if (context.mounted) context.go('/activation');
            },
          ),
          const Divider(),
          ListTile(
            title: const Text('Reset Everything'),
            subtitle: const Text('Clear all data and start from scratch'),
            leading: const Icon(Icons.delete_forever, color: AppTheme.error),
            onTap: () => _resetEverything(context),
          ),
        ],
      ),
    );
  }
}
