import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../app/theme/app_theme.dart';
import '../../core/api/ocr_service.dart';
import '../../core/models/captured_report.dart';
import '../../core/models/extraction_result.dart';
import '../../core/models/ocr_job.dart';
import '../extract/extract_screen.dart';

class ReaderScreen extends StatefulWidget {
  final CapturedReport report;

  const ReaderScreen({super.key, required this.report});

  @override
  State<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends State<ReaderScreen> {
  final _ocr = OcrService();

  _ReaderState _state = const _Uploading(0);

  @override
  void initState() {
    super.initState();
    _run();
  }

  Future<void> _run() async {
    setState(() => _state = const _Uploading(0));
    try {
      final jobId = await _ocr.submitJob(
        widget.report.file,
        onProgress: (p) {
          if (mounted) setState(() => _state = _Uploading(p));
        },
      );

      setState(() => _state = const _Polling());

      await for (final job in _ocr.pollJob(jobId)) {
        if (!mounted) return;
        if (job.status == OcrJobStatus.failed) {
          setState(() => _state = _Failed(job.error ?? 'Processing failed.'));
          return;
        }
        if (job.status == OcrJobStatus.completed) {
          if (!mounted) return;
          final extraction =
              ExtractionResult.fromJson(job.result ?? {});
          await Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => ExtractScreen(extraction: extraction),
            ),
          );
          if (mounted) context.go('/home');
          return;
        }
      }
    } on OcrServiceException catch (e) {
      if (mounted) setState(() => _state = _Failed(e.message));
    } catch (_) {
      if (mounted) {
        setState(() => _state = const _Failed('An unexpected error occurred.'));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _state is _Failed,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Analysing Report'),
          automaticallyImplyLeading: _state is _Failed,
        ),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: switch (_state) {
              _Uploading(progress: final p) => _UploadingView(progress: p),
              _Polling() => const _PollingView(),
              _Failed(message: final msg) => _FailedView(
                  message: msg,
                  onRetry: _run,
                  onCancel: () => context.go('/home'),
                ),
            },
          ),
        ),
      ),
    );
  }
}

// ── State types ──────────────────────────────────────────────────────────────

sealed class _ReaderState {
  const _ReaderState();
}

class _Uploading extends _ReaderState {
  final double progress;
  const _Uploading(this.progress);
}

class _Polling extends _ReaderState {
  const _Polling();
}

class _Failed extends _ReaderState {
  final String message;
  const _Failed(this.message);
}

// ── View widgets ─────────────────────────────────────────────────────────────

class _UploadingView extends StatelessWidget {
  final double progress;
  const _UploadingView({required this.progress});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Icon(Icons.cloud_upload_outlined, size: 64, color: AppTheme.primary),
        const SizedBox(height: 24),
        const Text('Uploading report…',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
        const SizedBox(height: 24),
        LinearProgressIndicator(
          value: progress > 0 ? progress : null,
          backgroundColor: AppTheme.primary.withAlpha(30),
          color: AppTheme.primary,
          minHeight: 8,
          borderRadius: BorderRadius.circular(4),
        ),
        const SizedBox(height: 12),
        if (progress > 0)
          Text(
            '${(progress * 100).toStringAsFixed(0)}%',
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppTheme.textSecondary),
          ),
        const SizedBox(height: 32),
        const _PrivacyNote(),
      ],
    );
  }
}

class _PollingView extends StatelessWidget {
  const _PollingView();

  @override
  Widget build(BuildContext context) {
    return const Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Icon(Icons.biotech_outlined, size: 64, color: AppTheme.primary),
        SizedBox(height: 24),
        Text('Processing report…',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
        SizedBox(height: 8),
        Text(
          'Extracting findings and removing identifying information.',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppTheme.textSecondary),
        ),
        SizedBox(height: 32),
        LinearProgressIndicator(
          backgroundColor: Color(0x1A1A3A5C),
          color: AppTheme.primary,
          minHeight: 8,
          borderRadius: BorderRadius.all(Radius.circular(4)),
        ),
        SizedBox(height: 32),
        _PrivacyNote(),
      ],
    );
  }
}

class _FailedView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  final VoidCallback onCancel;

  const _FailedView({
    required this.message,
    required this.onRetry,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Icon(Icons.error_outline, size: 64, color: AppTheme.error),
        const SizedBox(height: 24),
        const Text('Processing failed',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppTheme.textSecondary),
        ),
        const SizedBox(height: 32),
        ElevatedButton(onPressed: onRetry, child: const Text('Try Again')),
        const SizedBox(height: 12),
        OutlinedButton(
          onPressed: onCancel,
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(double.infinity, 56),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: const Text('Cancel'),
        ),
      ],
    );
  }
}

class _PrivacyNote extends StatelessWidget {
  const _PrivacyNote();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.shield_outlined, size: 14, color: AppTheme.textSecondary),
        const SizedBox(width: 6),
        const Text(
          'Report is processed securely on Resolara servers.',
          style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
        ),
      ],
    );
  }
}
