import 'dart:io';
import 'dart:typed_data';
import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:go_router/go_router.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:share_plus/share_plus.dart' show Share, XFile;
import '../../app/theme/app_theme.dart';
import '../../core/api/api_client.dart';
import '../../core/models/extraction_result.dart';
import '../../core/models/generation_job.dart';
import '../../core/storage/app_database.dart';
import '../../core/storage/secure_file_storage.dart';
import '../../shared/widgets/error_view.dart';
import '../../shared/widgets/loading_overlay.dart';

// Unicode circled numbers ①–⑳
String _circledNumber(int n) {
  const circles = ['①','②','③','④','⑤','⑥','⑦','⑧','⑨','⑩',
                   '⑪','⑫','⑬','⑭','⑮','⑯','⑰','⑱','⑲','⑳'];
  if (n >= 1 && n <= circles.length) return circles[n - 1];
  return '$n.';
}

class ReviewScreen extends StatefulWidget {
  final GenerationJob job;
  final List<Finding> findings;

  const ReviewScreen({super.key, required this.job, required this.findings});

  @override
  State<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends State<ReviewScreen> {
  _ReviewState _state = const _Loading();
  late List<Finding> _editableFindings;

  @override
  void initState() {
    super.initState();
    _editableFindings = List.of(widget.findings);
    _loadImage();
  }

  Future<void> _loadImage() async {
    setState(() => _state = const _Loading());
    try {
      final imageUrl = widget.job.imageUrl;
      if (imageUrl == null) {
        setState(() =>
            _state = const _Failed('No image URL returned from server.'));
        return;
      }

      final response = await ApiClient.instance.dio.get<Uint8List>(
        imageUrl,
        options: Options(responseType: ResponseType.bytes),
      );

      if (response.data == null) {
        setState(() => _state = const _Failed('Could not load image.'));
        return;
      }

      if (mounted) setState(() => _state = _Ready(response.data!));
    } catch (e) {
      if (mounted) {
        setState(() => _state = _Failed('Failed to load visualization: $e'));
      }
    }
  }

  Future<void> _approve(Uint8List imageBytes) async {
    setState(() => _state = const _Saving());
    try {
      final now = DateTime.now();
      final dir = await getApplicationDocumentsDirectory();
      final savedDir = Directory(p.join(dir.path, 'approved_visualizations'));
      if (!savedDir.existsSync()) savedDir.createSync(recursive: true);

      final filename = 'resolara_${now.millisecondsSinceEpoch}.enc';
      final dest = File(p.join(savedDir.path, filename));

      await SecureFileStorage.writeEncrypted(dest, imageBytes);

      final db = await openAppDatabase();
      final regions = _editableFindings
          .map((f) => f.bodyRegion)
          .toSet()
          .toList()
          .join(',');
      final retainUntil =
          now.add(const Duration(days: 90)).millisecondsSinceEpoch;
      await db.insertVisualization(VisualizationsCompanion(
        jobId: Value(widget.job.jobId),
        imagePath: Value(dest.path),
        createdAt: Value(now.millisecondsSinceEpoch),
        bodyRegions: Value(regions),
        findingCount: Value(_editableFindings.length),
        retainUntil: Value(retainUntil),
      ));

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Visualization saved.')),
      );
      context.go('/history');
    } catch (_) {
      if (mounted) setState(() => _state = _Ready((_state as _Ready).imageBytes));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Save failed. Please try again.')),
        );
      }
    }
  }

  Future<void> _share(Uint8List imageBytes) async {
    final tmp = await getTemporaryDirectory();
    final file = File(p.join(tmp.path, 'resolara_visualization.png'));
    await file.writeAsBytes(imageBytes);
    await Share.shareXFiles(
      [XFile(file.path, mimeType: 'image/png')],
      subject: 'Resolara Visualization',
    );
  }

  Future<void> _showDetails(Uint8List imageBytes) async {
    final updated = await showModalBottomSheet<List<Finding>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _DetailsSheet(findings: _editableFindings),
    );

    if (updated == null || !mounted) return;

    final changed = _findingsChanged(updated);
    setState(() => _editableFindings = updated);

    if (!changed) return;

    final regen = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Findings updated'),
        content: const Text(
          'The findings have been edited. Regenerate the visualization with the updated findings?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Keep current'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Regenerate'),
          ),
        ],
      ),
    );

    if (regen == true && mounted) {
      Navigator.of(context).pop(updated);
    }
  }

  bool _findingsChanged(List<Finding> updated) {
    if (updated.length != widget.findings.length) return true;
    for (var i = 0; i < updated.length; i++) {
      if (updated[i].text != widget.findings[i].text ||
          updated[i].bodyRegion != widget.findings[i].bodyRegion) {
        return true;
      }
    }
    return false;
  }

  void _regenerate() {
    Navigator.of(context).pop(_editableFindings);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _state is! _Saving,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Review Visualization'),
          automaticallyImplyLeading: _state is! _Saving,
        ),
        body: switch (_state) {
          _Loading() => const Center(
              child: CircularProgressIndicator(color: AppTheme.accent)),
          _Saving() => const LoadingOverlay(message: 'Saving…'),
          _Failed(message: final msg) => ErrorView(
              message: msg,
              onRetry: _loadImage,
            ),
          _Ready(imageBytes: final bytes) => _ReadyView(
              imageBytes: bytes,
              findings: _editableFindings,
              onApprove: () => _approve(bytes),
              onRegenerate: _regenerate,
              onShare: () => _share(bytes),
              onDetails: () => _showDetails(bytes),
            ),
        },
      ),
    );
  }
}

// ── State types ───────────────────────────────────────────────────────────────

sealed class _ReviewState {
  const _ReviewState();
}

class _Loading extends _ReviewState {
  const _Loading();
}

class _Saving extends _ReviewState {
  const _Saving();
}

class _Failed extends _ReviewState {
  final String message;
  const _Failed(this.message);
}

class _Ready extends _ReviewState {
  final Uint8List imageBytes;
  const _Ready(this.imageBytes);
}

// ── Ready view ────────────────────────────────────────────────────────────────

class _ReadyView extends StatelessWidget {
  final Uint8List imageBytes;
  final List<Finding> findings;
  final VoidCallback onApprove;
  final VoidCallback onRegenerate;
  final VoidCallback onShare;
  final VoidCallback onDetails;

  const _ReadyView({
    required this.imageBytes,
    required this.findings,
    required this.onApprove,
    required this.onRegenerate,
    required this.onShare,
    required this.onDetails,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: GestureDetector(
            onTap: () => Navigator.of(context).push(
              PageRouteBuilder(
                opaque: false,
                pageBuilder: (_, __, ___) =>
                    _FullScreenImage(imageBytes: imageBytes),
              ),
            ),
            child: Container(
              color: AppTheme.forestTeal,
              child: Hero(
                tag: 'viz_preview',
                child: Image.memory(imageBytes, fit: BoxFit.contain),
              ),
            ),
          ),
        ),
        _ActionBar(
          onApprove: onApprove,
          onRegenerate: onRegenerate,
          onShare: onShare,
          onDetails: onDetails,
        ),
      ],
    );
  }
}

// ── Full-screen image overlay ─────────────────────────────────────────────────

class _FullScreenImage extends StatelessWidget {
  final Uint8List imageBytes;
  const _FullScreenImage({required this.imageBytes});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.of(context).pop(),
      child: Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          child: Stack(
            children: [
              Center(
                child: Hero(
                  tag: 'viz_preview',
                  child: Image.memory(imageBytes, fit: BoxFit.contain),
                ),
              ),
              Positioned(
                top: 12,
                right: 16,
                child: GestureDetector(
                  onTap: () => Navigator.of(context).pop(),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    padding: const EdgeInsets.all(6),
                    child: const Icon(Icons.close, color: Colors.white, size: 22),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Action bar ────────────────────────────────────────────────────────────────

class _ActionBar extends StatelessWidget {
  final VoidCallback onApprove;
  final VoidCallback onRegenerate;
  final VoidCallback onShare;
  final VoidCallback onDetails;

  const _ActionBar({
    required this.onApprove,
    required this.onRegenerate,
    required this.onShare,
    required this.onDetails,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppTheme.surface,
        border: Border(top: BorderSide(color: AppTheme.sage, width: 0.5)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ElevatedButton.icon(
            onPressed: onApprove,
            icon: const Icon(Icons.check_circle_outline),
            label: const Text('Approve & Save'),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onRegenerate,
                  icon: const Icon(Icons.refresh, size: 18),
                  label: const Text('Regenerate'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onShare,
                  icon: const Icon(Icons.share_outlined, size: 18),
                  label: const Text('Share'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          TextButton.icon(
            onPressed: onDetails,
            icon: const Icon(Icons.list_alt_outlined, size: 18),
            label: const Text('View / Edit Findings'),
          ),
        ],
      ),
    );
  }
}

// ── Details bottom sheet ──────────────────────────────────────────────────────

class _DetailsSheet extends StatefulWidget {
  final List<Finding> findings;
  const _DetailsSheet({required this.findings});

  @override
  State<_DetailsSheet> createState() => _DetailsSheetState();
}

class _DetailsSheetState extends State<_DetailsSheet> {
  late final List<TextEditingController> _textControllers;
  late final List<TextEditingController> _regionControllers;

  @override
  void initState() {
    super.initState();
    _textControllers = widget.findings
        .map((f) => TextEditingController(text: f.text))
        .toList();
    _regionControllers = widget.findings
        .map((f) => TextEditingController(text: f.bodyRegion))
        .toList();
  }

  @override
  void dispose() {
    for (final c in _textControllers) c.dispose();
    for (final c in _regionControllers) c.dispose();
    super.dispose();
  }

  List<Finding> _buildUpdated() {
    return List.generate(widget.findings.length, (i) {
      return widget.findings[i].copyWith(
        text: _textControllers[i].text.trim(),
        bodyRegion: _regionControllers[i].text.trim(),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return DraggableScrollableSheet(
      initialChildSize: 0.65,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // Handle
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
              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                child: Row(
                  children: [
                    const Icon(Icons.list_alt_outlined,
                        size: 20, color: AppTheme.accent),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'Findings',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textPrimary,
                        ),
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
              // Findings list
              Expanded(
                child: ListView.separated(
                  controller: scrollController,
                  padding: EdgeInsets.fromLTRB(20, 12, 20, bottomInset + 12),
                  itemCount: widget.findings.length,
                  separatorBuilder: (_, __) =>
                      const Divider(height: 24, color: AppTheme.sage),
                  itemBuilder: (context, i) => _FindingEditor(
                    number: i + 1,
                    textController: _textControllers[i],
                    regionController: _regionControllers[i],
                  ),
                ),
              ),
              // Save button
              Padding(
                padding: EdgeInsets.fromLTRB(20, 8, 20, bottomInset + 20),
                child: ElevatedButton.icon(
                  onPressed: () =>
                      Navigator.of(context).pop(_buildUpdated()),
                  icon: const Icon(Icons.check_outlined),
                  label: const Text('Save Findings'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ── Single finding editor row ─────────────────────────────────────────────────

class _FindingEditor extends StatelessWidget {
  final int number;
  final TextEditingController textController;
  final TextEditingController regionController;

  const _FindingEditor({
    required this.number,
    required this.textController,
    required this.regionController,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              _circledNumber(number),
              style: const TextStyle(
                fontSize: 16,
                color: AppTheme.gold,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                controller: regionController,
                style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w500),
                decoration: const InputDecoration(
                  labelText: 'Body region',
                  isDense: true,
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        TextField(
          controller: textController,
          maxLines: null,
          style: const TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w400),
          decoration: const InputDecoration(
            labelText: 'Finding',
            alignLabelWithHint: true,
            contentPadding:
                EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          ),
        ),
      ],
    );
  }
}
