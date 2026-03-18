import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../app/theme/app_theme.dart';
import '../../core/storage/app_database.dart';
import '../../core/storage/secure_file_storage.dart';

class HistoryDetailScreen extends StatefulWidget {
  final Visualization record;

  const HistoryDetailScreen({super.key, required this.record});

  @override
  State<HistoryDetailScreen> createState() => _HistoryDetailScreenState();
}

class _HistoryDetailScreenState extends State<HistoryDetailScreen> {
  late final Future<Uint8List?> _imageFuture;

  @override
  void initState() {
    super.initState();
    _imageFuture =
        SecureFileStorage.readDecrypted(File(widget.record.imagePath));
  }

  String _formatDate(int ms) {
    final d = DateTime.fromMillisecondsSinceEpoch(ms);
    return '${d.day.toString().padLeft(2, '0')} '
        '${_month(d.month)} ${d.year}  '
        '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }

  String _month(int m) => const [
        '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
      ][m];

  Future<void> _confirmDelete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete visualization?'),
        content: const Text(
            'This will permanently remove the image and its record.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppTheme.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    // Delete DB record first — this always succeeds even if file is missing
    final db = await openAppDatabase();
    await db.deleteVisualization(widget.record.id);

    // Delete file in background — non-blocking, won't hang UI if file is gone
    try {
      final f = File(widget.record.imagePath);
      if (await f.exists()) await f.delete();
    } catch (_) {} // silently ignore — record is already gone

    if (context.mounted) context.go('/history');
  }

  @override
  Widget build(BuildContext context) {
    final regions = widget.record.bodyRegions.isNotEmpty
        ? widget.record.bodyRegions.split(',').map((s) => s.trim()).toList()
        : <String>[];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Visualization'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline, color: AppTheme.error),
            tooltip: 'Delete',
            onPressed: () => _confirmDelete(context),
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Container(
              color: Colors.black,
              child: FutureBuilder<Uint8List?>(
                future: _imageFuture,
                builder: (context, snap) {
                  if (snap.connectionState != ConnectionState.done) {
                    return const Center(
                        child: CircularProgressIndicator(
                            color: AppTheme.accent));
                  }
                  if (snap.data != null) {
                    return Image.memory(snap.data!, fit: BoxFit.contain);
                  }
                  return const Center(
                      child: Icon(Icons.broken_image_outlined,
                          size: 64, color: AppTheme.textSecondary));
                },
              ),
            ),
          ),
          Container(
            color: AppTheme.surface,
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _MetaRow(
                    icon: Icons.calendar_today_outlined,
                    label: _formatDate(widget.record.createdAt)),
                const SizedBox(height: 10),
                _MetaRow(
                    icon: Icons.pin_outlined,
                    label:
                        '${widget.record.findingCount} finding${widget.record.findingCount == 1 ? '' : 's'}'),
                if (regions.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  _MetaRow(
                      icon: Icons.place_outlined,
                      label: regions.join(' · ')),
                ],
                const SizedBox(height: 16),
                const Text(
                  'Generated from de-identified findings only. Not for diagnostic use.',
                  style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MetaRow extends StatelessWidget {
  final IconData icon;
  final String label;
  const _MetaRow({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppTheme.textSecondary),
        const SizedBox(width: 8),
        Expanded(
          child: Text(label,
              style: const TextStyle(
                  color: AppTheme.textPrimary, fontSize: 14)),
        ),
      ],
    );
  }
}
