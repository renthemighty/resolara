import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import '../../app/theme/app_theme.dart';
import '../../core/api/api_client.dart';
import '../../core/services/session_service.dart';
import '../../core/storage/app_database.dart';
import '../generate/generate_screen.dart';

class SessionsScreen extends StatefulWidget {
  const SessionsScreen({super.key});

  @override
  State<SessionsScreen> createState() => _SessionsScreenState();
}

class _SessionsScreenState extends State<SessionsScreen> {
  late final Future<AppDatabase> _dbFuture;

  @override
  void initState() {
    super.initState();
    _dbFuture = openAppDatabase();
  }

  Future<void> _deleteSession(AppDatabase db, Session session) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove session?'),
        content: const Text('This will remove the session record.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppTheme.error),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed == true) await db.deleteSession(session.id);
  }

  void _resumeSession(Session session) {
    if (session.vizJobId == null || session.findingsJson == null) return;
    final findings = SessionService.decodeFindings(session.findingsJson!);
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => GenerateScreen(
          findings: findings,
          resumeSessionId: session.id,
          resumeVizJobId: session.vizJobId,
        ),
      ),
    );
  }

  void _viewSession(Session session) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _SessionDetailSheet(session: session),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sessions')),
      body: FutureBuilder<AppDatabase>(
        future: _dbFuture,
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(
                child: CircularProgressIndicator(color: AppTheme.accent));
          }
          final db = snap.data!;
          return StreamBuilder<List<Session>>(
            stream: db.watchSessions(),
            builder: (context, snap) {
              if (!snap.hasData) {
                return const Center(
                    child: CircularProgressIndicator(color: AppTheme.accent));
              }
              final sessions = snap.data!;
              if (sessions.isEmpty) return const _EmptySessions();

              // Split into active and recent
              final active =
                  sessions.where((s) => s.status == 'generating').toList();
              final recent =
                  sessions.where((s) => s.status != 'generating').toList();

              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (active.isNotEmpty) ...[
                    _SectionHeader(
                        icon: Icons.sync_outlined,
                        label: 'Active (${active.length})'),
                    const SizedBox(height: 8),
                    ...active.map((s) => _SessionCard(
                          session: s,
                          onResume: () => _resumeSession(s),
                          onDelete: () => _deleteSession(db, s),
                        )),
                    const SizedBox(height: 16),
                  ],
                  if (recent.isNotEmpty) ...[
                    _SectionHeader(
                        icon: Icons.history_outlined,
                        label: 'Recent (${recent.length})'),
                    const SizedBox(height: 8),
                    ...recent.map((s) => _SessionCard(
                          session: s,
                          onView: () => _viewSession(s),
                          onDelete: () => _deleteSession(db, s),
                        )),
                  ],
                  const SizedBox(height: 32),
                  _TotalsCard(sessions: sessions),
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

class _EmptySessions extends StatelessWidget {
  const _EmptySessions();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.auto_awesome_outlined,
                size: 56, color: AppTheme.textSecondary),
            SizedBox(height: 16),
            Text(
              'No sessions yet.\nStart a generation to see it tracked here.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppTheme.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Section header ────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String label;
  const _SectionHeader({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 14, color: AppTheme.textSecondary),
        const SizedBox(width: 6),
        Text(
          label.toUpperCase(),
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: AppTheme.textSecondary,
            letterSpacing: 0.8,
          ),
        ),
      ],
    );
  }
}

// ── Session card ──────────────────────────────────────────────────────────────

class _SessionCard extends StatelessWidget {
  final Session session;
  final VoidCallback? onResume;
  final VoidCallback? onView;
  final VoidCallback onDelete;

  const _SessionCard({
    required this.session,
    this.onResume,
    this.onView,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final isActive = session.status == 'generating';
    final regions = session.bodyRegions.isNotEmpty
        ? session.bodyRegions.split(',').map((s) => s.trim()).join(' · ')
        : 'Unknown region';
    final date = _formatDate(session.startedAt);

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: isActive ? onResume : onView,
        onLongPress: onDelete,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _StatusBadge(status: session.status),
                  const Spacer(),
                  if (isActive)
                    TextButton.icon(
                      onPressed: onResume,
                      icon: const Icon(Icons.play_arrow_outlined, size: 16),
                      label: const Text('Resume',
                          style: TextStyle(fontSize: 12)),
                      style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4)),
                    ),
                  IconButton(
                    icon: const Icon(Icons.close,
                        size: 16, color: AppTheme.textSecondary),
                    onPressed: onDelete,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                regions,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  color: Theme.of(context).brightness == Brightness.dark
                      ? AppTheme.warmStone
                      : AppTheme.emerald,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  _Stat(
                      label: '${session.findingCount} finding${session.findingCount == 1 ? '' : 's'}'),
                  if (session.tokensIn > 0 || session.tokensOut > 0) ...[
                    const _Dot(),
                    _Stat(label: SessionService.formatTokens(session)),
                    const _Dot(),
                    _Stat(
                        label: SessionService.formatCost(session),
                        highlight: true),
                  ],
                ],
              ),
              const SizedBox(height: 4),
              Text(
                date,
                style: const TextStyle(
                    fontSize: 11, color: AppTheme.textSecondary),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(int ms) {
    final d = DateTime.fromMillisecondsSinceEpoch(ms);
    final months = const [
      '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${d.day} ${months[d.month]} ${d.year}  '
        '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }
}

// ── Status badge ──────────────────────────────────────────────────────────────

class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      'generating' => ('Generating', AppTheme.accent),
      'completed'  => ('Completed', const Color(0xFF4CAF7D)),
      'failed'     => ('Failed', AppTheme.error),
      _            => (status, AppTheme.textSecondary),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withAlpha(30),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withAlpha(80)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (status == 'generating') ...[
            SizedBox(
              width: 10,
              height: 10,
              child: CircularProgressIndicator(
                  strokeWidth: 1.5, color: color),
            ),
            const SizedBox(width: 5),
          ],
          Text(
            label,
            style: TextStyle(
                fontSize: 11, fontWeight: FontWeight.w600, color: color),
          ),
        ],
      ),
    );
  }
}

// ── Totals card ───────────────────────────────────────────────────────────────

class _TotalsCard extends StatelessWidget {
  final List<Session> sessions;
  const _TotalsCard({required this.sessions});

  @override
  Widget build(BuildContext context) {
    final completed =
        sessions.where((s) => s.status == 'completed').length;
    final failed = sessions.where((s) => s.status == 'failed').length;
    final totalTokensIn =
        sessions.fold<int>(0, (sum, s) => sum + s.tokensIn);
    final totalTokensOut =
        sessions.fold<int>(0, (sum, s) => sum + s.tokensOut);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF1E4535), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'ALL SESSIONS',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppTheme.textSecondary,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _AnalyticsTile(
                  label: 'Completed', value: '$completed'),
              _AnalyticsTile(
                  label: 'Failed', value: '$failed'),
              _AnalyticsTile(
                  label: 'Total',
                  value: '${sessions.length}'),
            ],
          ),
          const Divider(height: 20, color: AppTheme.sage),
          Row(
            children: [
              _AnalyticsTile(
                label: 'Input tokens',
                value: _fmtTokens(totalTokensIn),
              ),
              _AnalyticsTile(
                label: 'Output tokens',
                value: _fmtTokens(totalTokensOut),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _fmtTokens(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}k';
    return '$n';
  }
}

class _AnalyticsTile extends StatelessWidget {
  final String label;
  final String value;
  final bool highlight;
  const _AnalyticsTile(
      {required this.label, required this.value, this.highlight = false});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: highlight ? AppTheme.gold : AppTheme.textPrimary,
              )),
          Text(label,
              style: const TextStyle(
                  fontSize: 11, color: AppTheme.textSecondary)),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String label;
  final bool highlight;
  const _Stat({required this.label, this.highlight = false});

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: TextStyle(
        fontSize: 12,
        color: highlight ? AppTheme.gold : AppTheme.textSecondary,
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot();
  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 5),
      child: Text('·',
          style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
    );
  }
}

// ── Session detail bottom sheet ───────────────────────────────────────────────

class _SessionDetailSheet extends StatefulWidget {
  final Session session;
  const _SessionDetailSheet({required this.session});

  @override
  State<_SessionDetailSheet> createState() => _SessionDetailSheetState();
}

class _SessionDetailSheetState extends State<_SessionDetailSheet> {
  Uint8List? _imageBytes;
  bool _imageLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.session.status == 'completed' && widget.session.imageUrl != null) {
      _loadImage(widget.session.imageUrl!);
    }
  }

  Future<void> _loadImage(String url) async {
    setState(() => _imageLoading = true);
    try {
      final response = await ApiClient.instance.dio.get<Uint8List>(
        url,
        options: Options(responseType: ResponseType.bytes),
      );
      if (mounted && response.data != null) {
        setState(() { _imageBytes = response.data; _imageLoading = false; });
      }
    } catch (_) {
      if (mounted) setState(() => _imageLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = widget.session;
    final findings = session.findingsJson != null
        ? SessionService.decodeFindings(session.findingsJson!)
        : <dynamic>[];
    final regions = session.bodyRegions.isNotEmpty
        ? session.bodyRegions.split(',').map((s) => s.trim()).toList()
        : <String>[];
    final date = _formatDate(session.startedAt);
    final tokens = SessionService.formatTokens(session);

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppTheme.sage.withAlpha(100),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                child: Row(
                  children: [
                    _StatusBadge(status: session.status),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        regions.isNotEmpty ? regions.join(' · ') : 'Session',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close,
                          size: 20, color: AppTheme.textSecondary),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, color: AppTheme.sage),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                  children: [
                    // Generated image
                    if (_imageLoading)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.symmetric(vertical: 24),
                          child: CircularProgressIndicator(color: AppTheme.accent),
                        ),
                      )
                    else if (_imageBytes != null) ...[
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.memory(_imageBytes!, fit: BoxFit.contain),
                      ),
                      const SizedBox(height: 16),
                    ],
                    // Meta row
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _InfoChip(label: date),
                        _InfoChip(label: '${session.findingCount} findings'),
                        if (session.tokensIn > 0 || session.tokensOut > 0)
                          _InfoChip(label: tokens),
                      ],
                    ),
                    if (session.errorMessage != null) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppTheme.error.withAlpha(20),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppTheme.error.withAlpha(60)),
                        ),
                        child: Text(
                          session.errorMessage!,
                          style: const TextStyle(
                              fontSize: 13, color: AppTheme.error),
                        ),
                      ),
                    ],
                    const SizedBox(height: 20),
                    if (findings.isNotEmpty) ...[
                      const Text(
                        'FINDINGS',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textSecondary,
                          letterSpacing: 0.8,
                        ),
                      ),
                      const SizedBox(height: 12),
                      ...findings.asMap().entries.map((entry) {
                        final i = entry.key;
                        final f = entry.value;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 14),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 24,
                                height: 24,
                                margin: const EdgeInsets.only(top: 2, right: 10),
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: AppTheme.gold.withAlpha(30),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                      color: AppTheme.gold.withAlpha(80)),
                                ),
                                child: Text(
                                  '${i + 1}',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: AppTheme.gold,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      f.bodyRegion.toUpperCase(),
                                      style: const TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                        color: AppTheme.textSecondary,
                                        letterSpacing: 0.6,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      f.text,
                                      style: const TextStyle(
                                        fontSize: 13,
                                        color: AppTheme.textPrimary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  String _formatDate(int ms) {
    final d = DateTime.fromMillisecondsSinceEpoch(ms);
    const months = [
      '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${d.day} ${months[d.month]} ${d.year}  '
        '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }
}

class _InfoChip extends StatelessWidget {
  final String label;
  final bool highlight;
  const _InfoChip({required this.label, this.highlight = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: highlight
            ? AppTheme.gold.withAlpha(25)
            : AppTheme.sage.withAlpha(30),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: highlight
              ? AppTheme.gold.withAlpha(80)
              : AppTheme.sage.withAlpha(60),
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w500,
          color: highlight ? AppTheme.gold : AppTheme.textSecondary,
        ),
      ),
    );
  }
}
