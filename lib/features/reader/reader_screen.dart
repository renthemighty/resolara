import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../app/theme/app_theme.dart';
import '../../core/api/ocr_service.dart';
import '../../core/models/captured_report.dart';
import '../../core/models/extraction_result.dart';
import '../../core/models/ocr_job.dart';
import '../../core/services/local_ocr_service.dart';
import '../../core/services/redaction_service.dart';
import '../extract/extract_screen.dart';

class ReaderScreen extends StatefulWidget {
  final CapturedReport report;

  const ReaderScreen({super.key, required this.report});

  @override
  State<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends State<ReaderScreen> {
  final _ocr = OcrService();
  final _localOcr = LocalOcrService();

  _ReaderState _state = const _ReadingReport();

  @override
  void initState() {
    super.initState();
    _run();
  }

  Future<void> _run() async {
    setState(() => _state = const _ReadingReport());

    try {
      // ── Phase 1: On-device OCR ─────────────────────────────────────────
      final String rawText;
      if (widget.report.isPdf) {
        rawText = await _localOcr.extractTextFromPdf(
          widget.report.file,
          onPageProgress: (page, total) {
            if (mounted) {
              setState(() => _state = _ReadingReport(page: page, totalPages: total));
            }
          },
        );
      } else {
        rawText = await _localOcr.extractTextFromImage(widget.report.file);
      }

      if (!mounted) return;

      if (rawText.trim().isEmpty) {
        setState(() => _state = const _Failed(
          'Could not read text from this report. Please try a clearer image.',
        ));
        return;
      }

      // ── Phase 2: On-device redaction ───────────────────────────────────
      final redaction = RedactionService.redact(rawText);

      // ── Phase 3: Submit cleaned text ───────────────────────────────────
      setState(() => _state = const _Submitting());

      final jobId = await _ocr.submitJob(
        cleanedReportText: redaction.redactedText,
        redactionSummary: redaction.summaryString,
        documentType: widget.report.isPdf ? 'pdf' : 'image',
        pageCount: 1,
      );

      if (!mounted) return;

      // ── Phase 4: Poll for findings ─────────────────────────────────────
      setState(() => _state = const _Polling());

      await for (final job in _ocr.pollJob(jobId)) {
        if (!mounted) return;
        if (job.status == OcrJobStatus.failed) {
          setState(() => _state = _Failed(job.error ?? 'Processing failed.'));
          return;
        }
        if (job.status == OcrJobStatus.completed) {
          final extraction = ExtractionResult.fromJson(job.result ?? {});
          await Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => ExtractScreen(extraction: extraction),
            ),
          );
          if (mounted) context.go('/home');
          return;
        }
      }
    } on LocalOcrException catch (e) {
      if (mounted) setState(() => _state = _Failed(e.message));
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
              _ReadingReport(page: final p, totalPages: final t) =>
                _ReadingReportView(page: p, totalPages: t),
              _Submitting() => const _SubmittingView(),
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

// ── State types ───────────────────────────────────────────────────────────────

sealed class _ReaderState {
  const _ReaderState();
}

class _ReadingReport extends _ReaderState {
  final int? page;
  final int? totalPages;
  const _ReadingReport({this.page, this.totalPages});
}

class _Submitting extends _ReaderState {
  const _Submitting();
}

class _Polling extends _ReaderState {
  const _Polling();
}

class _Failed extends _ReaderState {
  final String message;
  const _Failed(this.message);
}

// ── View widgets ──────────────────────────────────────────────────────────────

class _ReadingReportView extends StatelessWidget {
  final int? page;
  final int? totalPages;

  const _ReadingReportView({this.page, this.totalPages});

  @override
  Widget build(BuildContext context) {
    final pageLabel = (page != null && totalPages != null)
        ? 'Reading page $page of $totalPages…'
        : 'Reading report…';

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Icon(Icons.document_scanner_outlined, size: 64, color: AppTheme.primary),
        const SizedBox(height: 24),
        Text(
          pageLabel,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        const Text(
          'Extracting text on your device.',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppTheme.textSecondary),
        ),
        const SizedBox(height: 24),
        const LinearProgressIndicator(
          backgroundColor: Color(0x1A1A3A5C),
          color: AppTheme.primary,
          minHeight: 8,
          borderRadius: BorderRadius.all(Radius.circular(4)),
        ),
        const SizedBox(height: 32),
        const _PrivacyNote(),
      ],
    );
  }
}

class _SubmittingView extends StatelessWidget {
  const _SubmittingView();

  @override
  Widget build(BuildContext context) {
    return const Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Icon(Icons.shield_outlined, size: 64, color: AppTheme.primary),
        SizedBox(height: 24),
        Text(
          'Sending report text…',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        SizedBox(height: 8),
        Text(
          'Identifying information has been removed. Only report text is transmitted.',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppTheme.textSecondary),
        ),
        SizedBox(height: 24),
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
        Text(
          'Extracting findings…',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        SizedBox(height: 8),
        Text(
          'Identifying clinically relevant information.',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppTheme.textSecondary),
        ),
        SizedBox(height: 24),
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
        const Text(
          'Processing failed',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
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
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
    return const Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.shield_outlined, size: 14, color: AppTheme.textSecondary),
        SizedBox(width: 6),
        Flexible(
          child: Text(
            'Images stay on your device. Only report text is transmitted.',
            style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
          ),
        ),
      ],
    );
  }
}
