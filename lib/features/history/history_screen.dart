import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../../app/theme/app_theme.dart';
import '../../core/storage/app_database.dart';
import '../../core/storage/secure_file_storage.dart';
import 'history_detail_screen.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  late final Future<AppDatabase> _dbFuture;
  String _search = '';

  @override
  void initState() {
    super.initState();
    _dbFuture = openAppDatabase();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('History')),
      body: FutureBuilder<AppDatabase>(
        future: _dbFuture,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(
                child: CircularProgressIndicator(color: AppTheme.accent));
          }
          return StreamBuilder<List<Visualization>>(
            stream: snapshot.data!.watchAll(),
            builder: (context, snap) {
              if (!snap.hasData) {
                return const Center(
                    child: CircularProgressIndicator(color: AppTheme.accent));
              }
              final all = snap.data!;
              final records = _search.isEmpty
                  ? all
                  : all.where((r) {
                      final q = _search.toLowerCase();
                      return (r.patientLabel ?? '').toLowerCase().contains(q);
                    }).toList();

              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                    child: TextField(
                      onChanged: (v) => setState(() => _search = v),
                      style: const TextStyle(fontSize: 14, color: AppTheme.textPrimary),
                      decoration: InputDecoration(
                        hintText: 'Search by patient label…',
                        hintStyle: const TextStyle(fontSize: 14, color: AppTheme.textSecondary),
                        prefixIcon: const Icon(Icons.search, size: 18, color: AppTheme.textSecondary),
                        isDense: true,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: AppTheme.sage),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: AppTheme.sage.withAlpha(120)),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                    ),
                  ),
                  Expanded(
                    child: records.isEmpty
                        ? const _EmptyHistory()
                        : ListView.separated(
                            padding: const EdgeInsets.all(16),
                            itemCount: records.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 10),
                            itemBuilder: (_, i) => _HistoryCard(record: records[i]),
                          ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

// ── Empty state ───────────────────────────────────────────────────────────────

class _EmptyHistory extends StatelessWidget {
  const _EmptyHistory();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.history, size: 56, color: AppTheme.textSecondary),
            SizedBox(height: 16),
            Text(
              'No saved visualizations yet.\nApproved reports will appear here.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppTheme.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

// ── History card ──────────────────────────────────────────────────────────────

class _HistoryCard extends StatefulWidget {
  final Visualization record;
  const _HistoryCard({required this.record});

  @override
  State<_HistoryCard> createState() => _HistoryCardState();
}

class _HistoryCardState extends State<_HistoryCard> {
  late final Future<Uint8List?> _thumbFuture;

  @override
  void initState() {
    super.initState();
    _thumbFuture =
        SecureFileStorage.readDecrypted(File(widget.record.imagePath));
  }

  String _formatDate(int ms) {
    final d = DateTime.fromMillisecondsSinceEpoch(ms);
    return '${d.day.toString().padLeft(2, '0')} '
        '${_month(d.month)} ${d.year}';
  }

  String _month(int m) => const [
        '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
      ][m];

  @override
  Widget build(BuildContext context) {
    final regions = widget.record.bodyRegions.isNotEmpty
        ? widget.record.bodyRegions.split(',').map((s) => s.trim()).join(' · ')
        : 'Unknown region';

    return GestureDetector(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => HistoryDetailScreen(record: widget.record),
        ),
      ),
      child: Card(
        child: Row(
          children: [
            ClipRRect(
              borderRadius:
                  const BorderRadius.horizontal(left: Radius.circular(16)),
              child: SizedBox(
                width: 88,
                height: 88,
                child: FutureBuilder<Uint8List?>(
                  future: _thumbFuture,
                  builder: (context, snap) {
                    if (snap.connectionState != ConnectionState.done) {
                      return const ColoredBox(
                        color: AppTheme.surface,
                        child: Center(
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppTheme.accent),
                          ),
                        ),
                      );
                    }
                    if (snap.data != null) {
                      return Image.memory(snap.data!, fit: BoxFit.cover);
                    }
                    return const ColoredBox(
                      color: AppTheme.surface,
                      child: Icon(Icons.image_outlined,
                          color: AppTheme.textSecondary),
                    );
                  },
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.record.patientLabel?.isNotEmpty == true
                          ? widget.record.patientLabel!
                          : regions,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: AppTheme.textPrimary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (widget.record.patientLabel?.isNotEmpty == true) ...[
                      const SizedBox(height: 2),
                      Text(
                        regions,
                        style: const TextStyle(
                            fontSize: 12, color: AppTheme.textSecondary),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const SizedBox(height: 4),
                    Text(
                      _formatDate(widget.record.createdAt),
                      style: const TextStyle(
                          fontSize: 12, color: AppTheme.textSecondary),
                    ),
                  ],
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.only(right: 12),
              child: Icon(Icons.chevron_right,
                  color: AppTheme.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}
