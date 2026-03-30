import 'package:flutter/material.dart';
import '../../app/theme/app_theme.dart';
import '../../core/storage/app_database.dart';
import 'patient_results_screen.dart';

class PatientSavedResultsScreen extends StatefulWidget {
  const PatientSavedResultsScreen({super.key});

  @override
  State<PatientSavedResultsScreen> createState() => _PatientSavedResultsScreenState();
}

class _PatientSavedResultsScreenState extends State<PatientSavedResultsScreen> {
  AppDatabase? _db;

  @override
  void initState() {
    super.initState();
    openAppDatabase().then((db) {
      if (!mounted) return;
      setState(() => _db = db);
    });
  }

  String _formatDate(int ms) {
    final d = DateTime.fromMillisecondsSinceEpoch(ms);
    return '${d.day}/${d.month}/${d.year}';
  }

  void _open(BuildContext context, String code) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PatientResultsScreen(shareCode: code),
      ),
    );
  }

  Future<void> _delete(String code) async {
    await _db?.deletePatientSaved(code);
  }

  @override
  Widget build(BuildContext context) {
    if (_db == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('My Results')),
      body: StreamBuilder<List<PatientSavedResult>>(
        stream: _db!.watchPatientSaved(),
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final items = snap.data!;
          if (items.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.folder_outlined,
                      size: 64,
                      color: AppTheme.textSecondary.withAlpha(80)),
                  const SizedBox(height: 16),
                  const Text(
                    'No saved results yet.',
                    style: TextStyle(
                        fontSize: 15, color: AppTheme.textSecondary),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Tap the bookmark icon when viewing results\nto save them here.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 13, color: AppTheme.textSecondary),
                  ),
                ],
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, i) {
              final item = items[i];
              final name = (item.patientName?.isNotEmpty == true)
                  ? item.patientName!
                  : 'Results — ${item.shareCode}';
              return Dismissible(
                key: ValueKey(item.shareCode),
                direction: DismissDirection.endToStart,
                background: Container(
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 20),
                  decoration: BoxDecoration(
                    color: AppTheme.error.withAlpha(200),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.delete_outline,
                      color: Colors.white, size: 22),
                ),
                onDismissed: (_) => _delete(item.shareCode),
                child: GestureDetector(
                  onTap: () => _open(context, item.shareCode),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: AppTheme.sage.withAlpha(60),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: AppTheme.gold.withAlpha(25),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.folder_outlined,
                              size: 22, color: AppTheme.gold),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(name,
                                  style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600)),
                              const SizedBox(height: 3),
                              Text(
                                'Saved ${_formatDate(item.savedAt)}',
                                style: const TextStyle(
                                    fontSize: 12,
                                    color: AppTheme.textSecondary),
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.chevron_right,
                            color: AppTheme.textSecondary, size: 20),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
