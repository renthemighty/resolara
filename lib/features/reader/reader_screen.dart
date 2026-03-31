import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
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
  final bool patientMode;

  const ReaderScreen({super.key, required this.report, this.patientMode = false});

  @override
  State<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends State<ReaderScreen> {
  final _ocr = OcrService();
  final _localOcr = LocalOcrService();

  _ReaderState _state = const _ReadingReport();
  int _runCount = 0;

  @override
  void initState() {
    super.initState();
    _run();
  }

  Future<void> _run() async {
    final runId = _runCount;
    setState(() => _state = const _ReadingReport());

    try {
      // ── Phase 1: On-device OCR ─────────────────────────────────────────
      final String rawText;
      if (widget.report.isPdf) {
        rawText = await _localOcr.extractTextFromPdf(
          widget.report.file,
          onPageProgress: (page, total) {
            if (mounted && runId == _runCount) {
              setState(() => _state = _ReadingReport(page: page, totalPages: total));
            }
          },
        );
      } else {
        rawText = await _localOcr.extractTextFromImage(widget.report.file);
      }

      if (!mounted || runId != _runCount) return;

      // Strip control characters (except tab/newline/CR) that can break
      // JSON parsing on the server when coming from PDF OCR.
      final cleanedRaw = rawText.replaceAll(
        RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F\x7F\x80-\x9F]'),
        '',
      );

      if (cleanedRaw.trim().isEmpty) {
        setState(() => _state = const _Failed(
          'Could not read text from this report. Please try a clearer image.',
        ));
        return;
      }

      // ── Phase 2: On-device redaction ───────────────────────────────────
      final redaction = RedactionService.redact(cleanedRaw);

      // ── Phase 3: Submit cleaned text ───────────────────────────────────
      setState(() => _state = const _Submitting());

      final jobId = await _ocr.submitJob(
        cleanedReportText: redaction.redactedText,
        redactionSummary: redaction.summaryString,
        documentType: widget.report.isPdf ? 'pdf' : 'image',
        pageCount: 1,
      );

      if (!mounted || runId != _runCount) return;

      // ── Phase 4: Poll for findings ─────────────────────────────────────
      setState(() => _state = const _Polling());

      await for (final job in _ocr.pollJob(jobId)) {
        if (!mounted || runId != _runCount) return;
        if (job.status == OcrJobStatus.failed) {
          setState(() => _state = _Failed(job.error ?? 'Processing failed.'));
          return;
        }
        if (job.status == OcrJobStatus.completed) {
          final extraction = ExtractionResult.fromJson(job.result ?? {})
              .withTokens(job.tokensIn, job.tokensOut);
          await Navigator.of(context).push(
            MaterialPageRoute(
              settings: const RouteSettings(name: '/extract'),
              builder: (_) => ExtractScreen(extraction: extraction, patientMode: widget.patientMode),
            ),
          );
          if (mounted) Navigator.of(context).popUntil((r) => r.isFirst);
          return;
        }
      }
    } on LocalOcrException catch (e) {
      if (mounted && runId == _runCount) setState(() => _state = _Failed(e.message));
    } on OcrServiceException catch (e) {
      if (mounted && runId == _runCount) setState(() => _state = _Failed(e.message));
    } on DioException catch (e) {
      if (mounted && runId == _runCount) {
        final msg = e.response?.statusCode != null
            ? 'Server error (${e.response!.statusCode}). Please try again.'
            : 'Could not reach server. Check your connection.';
        setState(() => _state = _Failed(msg));
      }
    } catch (e) {
      if (mounted && runId == _runCount) {
        final msg = e.toString().contains('objective_c') || e.toString().contains('pdfx')
            ? 'PDF processing is not supported on this device. Please try a JPEG or PNG image instead.'
            : 'An unexpected error occurred. Please try again.';
        setState(() => _state = _Failed(msg));
      }
    }
  }

  void _stop() {
    _runCount++;
    Navigator.of(context).pop();
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
                _ReadingReportView(page: p, totalPages: t, onStop: _stop),
              _Submitting() => _SubmittingView(onStop: _stop),
              _Polling() => _PollingView(onStop: _stop),
              _Failed(message: final msg) => _FailedView(
                  message: msg,
                  onRetry: _run,
                  onCancel: () => Navigator.of(context).popUntil((r) => r.isFirst),
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
  final VoidCallback onStop;

  const _ReadingReportView({this.page, this.totalPages, required this.onStop});

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
        const SizedBox(height: 24),
        _StopButton(onStop: onStop),
      ],
    );
  }
}

class _SubmittingView extends StatelessWidget {
  final VoidCallback onStop;
  const _SubmittingView({required this.onStop});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Icon(Icons.biotech_outlined, size: 64, color: AppTheme.primary),
        const SizedBox(height: 24),
        const Text(
          'Extracting findings…',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        const Text(
          'Identifying clinically relevant information.',
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
        const SizedBox(height: 24),
        _StopButton(onStop: onStop),
      ],
    );
  }
}

class _PollingView extends StatelessWidget {
  final VoidCallback onStop;
  const _PollingView({required this.onStop});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Icon(Icons.shield_outlined, size: 64, color: AppTheme.primary),
        const SizedBox(height: 24),
        const Text(
          'Extracting report text…',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 24),
        const LinearProgressIndicator(
          backgroundColor: Color(0x1A1A3A5C),
          color: AppTheme.primary,
          minHeight: 8,
          borderRadius: BorderRadius.all(Radius.circular(4)),
        ),
        const SizedBox(height: 24),
        _StopButton(onStop: onStop),
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
    return SingleChildScrollView(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 16),
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
      ),
    );
  }
}

class _StopButton extends StatelessWidget {
  final VoidCallback onStop;
  const _StopButton({required this.onStop});

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onStop,
      style: OutlinedButton.styleFrom(
        foregroundColor: AppTheme.error,
        side: const BorderSide(color: AppTheme.error),
        minimumSize: const Size(double.infinity, 48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      child: const Text('Cancel'),
    );
  }
}
