import 'package:flutter/material.dart';
import '../../core/models/captured_report.dart';
import '../reader/reader_screen.dart';

class PreviewScreen extends StatelessWidget {
  final CapturedReport report;
  final bool patientMode;

  const PreviewScreen({super.key, required this.report, this.patientMode = false});

  Future<void> _confirm(BuildContext context) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => ReaderScreen(report: report, patientMode: patientMode)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Review Image'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
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
                  onPressed: () => Navigator.of(context).pop(),
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
