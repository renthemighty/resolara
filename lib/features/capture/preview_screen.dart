import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/models/captured_report.dart';
import '../../app/theme/app_theme.dart';
import '../reader/reader_screen.dart';

class PreviewScreen extends StatelessWidget {
  final CapturedReport report;

  const PreviewScreen({super.key, required this.report});

  Future<void> _confirm(BuildContext context) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => ReaderScreen(report: report)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Review Image'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/home'),
        ),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Container(
              color: Colors.black,
              child: Image.file(report.file, fit: BoxFit.contain),
            ),
          ),
          _InfoBanner(),
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ElevatedButton(
                  onPressed: () => _confirm(context),
                  child: const Text('Use This Image'),
                ),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: () => context.go('/home'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 56),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Retake / Choose Different'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoBanner extends StatelessWidget {
  const _InfoBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppTheme.primary.withAlpha(20),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: const Row(
        children: [
          Icon(Icons.shield_outlined, size: 16, color: AppTheme.primary),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'Report text will be de-identified before analysis. Image stays on your device.',
              style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}
