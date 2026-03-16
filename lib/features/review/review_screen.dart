import 'dart:io';
import 'dart:typed_data';
import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:go_router/go_router.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import '../../app/theme/app_theme.dart';
import '../../core/api/api_client.dart';
import '../../core/models/extraction_result.dart';
import '../../core/models/generation_job.dart';
import '../../core/storage/app_database.dart';
import '../../shared/widgets/error_view.dart';
import '../../shared/widgets/loading_overlay.dart';

class ReviewScreen extends StatefulWidget {
  final GenerationJob job;
  final List<Finding> findings;

  const ReviewScreen({super.key, required this.job, required this.findings});

  @override
  State<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends State<ReviewScreen> {
  _ReviewState _state = const _Loading();

  @override
  void initState() {
    super.initState();
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

      final dir = await getTemporaryDirectory();
      final tmpFile = File(
          p.join(dir.path, 'resolara_preview_${widget.job.jobId}.jpg'));
      await tmpFile.writeAsBytes(response.data!);

      if (mounted) setState(() => _state = _Ready(tmpFile));
    } catch (e) {
      if (mounted) {
        setState(() => _state = _Failed('Failed to load visualization: $e'));
      }
    }
  }

  Future<void> _approve(File imageFile) async {
    setState(() => _state = const _Saving());
    try {
      final now = DateTime.now();
      final dir = await getApplicationDocumentsDirectory();
      final savedDir = Directory(p.join(dir.path, 'approved_visualizations'));
      if (!savedDir.existsSync()) savedDir.createSync(recursive: true);

      final filename = 'resolara_${now.millisecondsSinceEpoch}.jpg';
      final dest = File(p.join(savedDir.path, filename));
      await imageFile.copy(dest.path);

      // Write metadata record to local DB
      final db = await openAppDatabase();
      final regions = widget.findings
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
        findingCount: Value(widget.findings.length),
        retainUntil: Value(retainUntil),
      ));

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Visualization saved.')),
      );
      context.go('/history');
    } catch (_) {
      if (mounted) setState(() => _state = _Ready(imageFile));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Save failed. Please try again.')),
        );
      }
    }
  }

  void _regenerate() {
    Navigator.of(context).pop(); // back to GenerateScreen which will retry
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
          _Ready(imageFile: final file) => _ReadyView(
              imageFile: file,
              jobId: widget.job.jobId,
              onApprove: () => _approve(file),
              onRegenerate: _regenerate,
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
  final File imageFile;
  const _Ready(this.imageFile);
}

// ── Ready view ────────────────────────────────────────────────────────────────

class _ReadyView extends StatelessWidget {
  final File imageFile;
  final String jobId;
  final VoidCallback onApprove;
  final VoidCallback onRegenerate;

  const _ReadyView({
    required this.imageFile,
    required this.jobId,
    required this.onApprove,
    required this.onRegenerate,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: Container(
            color: AppTheme.forestTeal,
            child: Image.file(imageFile, fit: BoxFit.contain),
          ),
        ),
        _MetaBar(jobId: jobId),
        _ActionBar(onApprove: onApprove, onRegenerate: onRegenerate),
      ],
    );
  }
}

class _MetaBar extends StatelessWidget {
  final String jobId;
  const _MetaBar({required this.jobId});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppTheme.surface,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          const Icon(Icons.info_outline, size: 14, color: AppTheme.textSecondary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Generated from de-identified findings only. Not for diagnostic use.',
              style: const TextStyle(
                  fontSize: 11, color: AppTheme.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionBar extends StatelessWidget {
  final VoidCallback onApprove;
  final VoidCallback onRegenerate;

  const _ActionBar({required this.onApprove, required this.onRegenerate});

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
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: onRegenerate,
            icon: const Icon(Icons.refresh),
            label: const Text('Regenerate'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.gold,
              side: const BorderSide(color: AppTheme.gold),
              minimumSize: const Size(double.infinity, 56),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }
}
