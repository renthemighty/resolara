import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:path_provider/path_provider.dart';
import '../../../app/theme/app_theme.dart';
import '../../../core/auth/auth_service.dart';
import '../../../core/config/app_config.dart';
import '../../../core/providers/theme_provider.dart';
import '../../../core/services/analytics_service.dart';
import '../../../core/services/session_service.dart';
import '../../../core/storage/app_database.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  Future<void> _resetEverything(BuildContext context, WidgetRef ref) async {
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

    Analytics.appReset();

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
      await db.delete(db.sessions).go();
    } catch (_) {}

    if (context.mounted) context.go('/onboarding');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider).valueOrNull ?? ThemeMode.system;
    Analytics.log('settings_screen_opened');

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          // ── Appearance ────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
            child: Text(
              'Appearance',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppTheme.textSecondary,
                letterSpacing: 0.8,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: SegmentedButton<ThemeMode>(
              segments: const [
                ButtonSegment(
                  value: ThemeMode.light,
                  icon: Icon(Icons.light_mode_outlined),
                  label: Text('Light'),
                ),
                ButtonSegment(
                  value: ThemeMode.system,
                  icon: Icon(Icons.brightness_auto_outlined),
                  label: Text('Auto'),
                ),
                ButtonSegment(
                  value: ThemeMode.dark,
                  icon: Icon(Icons.dark_mode_outlined),
                  label: Text('Dark'),
                ),
              ],
              selected: {themeMode},
              onSelectionChanged: (selection) {
                  final mode = selection.first;
                  ref.read(themeModeProvider.notifier).setMode(mode);
                  Analytics.themeChanged(mode.name);
                },
            ),
          ),
          const Divider(height: 24),
          // ── History ───────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Text(
              'Visualizations',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppTheme.textSecondary,
                letterSpacing: 0.8,
              ),
            ),
          ),
          ListTile(
            title: const Text('Saved Visualizations'),
            subtitle: const Text('View your approved visualization history'),
            leading: const Icon(Icons.history_outlined, color: AppTheme.accent),
            trailing: const Icon(Icons.chevron_right, color: AppTheme.textSecondary),
            onTap: () {
              Analytics.historyOpened();
              context.push('/history');
            },
          ),
          const Divider(height: 24),
          // ── Account ───────────────────────────────────────────────────────
          ListTile(
            title: const Text('Sign Out'),
            leading: const Icon(Icons.logout, color: AppTheme.textSecondary),
            onTap: () async {
              Analytics.practitionerLoggedOut();
              await AuthService().clearAll();
              if (context.mounted) context.go('/onboarding');
            },
          ),
          const Divider(),
          ListTile(
            title: const Text('Reset Everything'),
            subtitle: const Text('Clear all data and start from scratch'),
            leading: const Icon(Icons.delete_forever, color: AppTheme.error),
            onTap: () => _resetEverything(context, ref),
          ),
          const Divider(height: 24),
          // ── Usage totals ──────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Text(
              'Usage',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppTheme.textSecondary,
                letterSpacing: 0.8,
              ),
            ),
          ),
          FutureBuilder<AppDatabase>(
            future: openAppDatabase(),
            builder: (context, snap) {
              if (!snap.hasData) return const SizedBox.shrink();
              return StreamBuilder<List<Session>>(
                stream: snap.data!.watchSessions(),
                builder: (context, snap) {
                  final sessions = snap.data ?? [];
                  final totalIn  = sessions.fold<int>(0, (s, e) => s + e.tokensIn);
                  final totalOut = sessions.fold<int>(0, (s, e) => s + e.tokensOut);
                  final completed = sessions.where((s) => s.status == 'completed').length;
                  final totalCost = sessions.fold<double>(
                      0, (s, e) => s + SessionService.estimateCost(e));
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppTheme.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFF1E4535)),
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              _UsageTile(label: 'Sessions', value: '${sessions.length}'),
                              _UsageTile(label: 'Completed', value: '$completed'),
                              _UsageTile(
                                label: 'Est. Cost',
                                value: totalCost < 0.001
                                    ? '—'
                                    : '\$${totalCost.toStringAsFixed(3)}',
                                highlight: true,
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              _UsageTile(label: 'Input tokens', value: _fmt(totalIn)),
                              _UsageTile(label: 'Output tokens', value: _fmt(totalOut)),
                              _UsageTile(label: 'Total tokens', value: _fmt(totalIn + totalOut)),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
          const Divider(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Column(
              children: [
                Text(
                  AppConfig.appName,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textSecondary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Version ${AppConfig.appVersion}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

String _fmt(int n) {
  if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
  if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}k';
  if (n == 0) return '—';
  return '$n';
}

class _UsageTile extends StatelessWidget {
  final String label;
  final String value;
  final bool highlight;
  const _UsageTile({required this.label, required this.value, this.highlight = false});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: highlight ? AppTheme.gold : AppTheme.textPrimary,
            ),
          ),
          Text(
            label,
            style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
          ),
        ],
      ),
    );
  }
}
