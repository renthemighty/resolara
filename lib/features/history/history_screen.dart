import 'package:flutter/material.dart';
import '../../../app/theme/app_theme.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('History')),
      body: const Center(
        child: Text(
          'No saved visualizations yet.',
          style: TextStyle(color: AppTheme.textSecondary),
        ),
      ),
    );
  }
}
