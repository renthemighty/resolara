import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import '../../app/theme/app_theme.dart';
import '../../core/api/ocr_service.dart';
import '../../core/models/captured_report.dart';
import '../../core/models/extraction_result.dart';
import '../../core/models/ocr_job.dart';
import '../../core/services/local_ocr_service.dart';
import '../../core/services/redaction/redaction.dart';
import '../extract/extract_screen.dart';
import '../redaction/redaction_approval.dart';

class ReaderScreen extends StatefulWidget {
  final CapturedReport? report;
  final CapturedBatch? batch;
  final bool patientMode;

  const ReaderScreen({super.key, this.report, this.batch, this.patientMode = false})
      : assert(report != null || batch != null, 'Provide report or batch');

  CapturedBatch get effectiveBatch =>
      batch ?? CapturedBatch([report!]);

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

  Future<ExtractionResult?> _processOneReport(CapturedReport report, int runId) async {
    // Phase 1: On-device OCR
    final String rawText;
    if (report.isPdf) {
      rawText = await _localOcr.extractTextFromPdf(
        report.file,
        onPageProgress: (page, total) {
          if (mounted && runId == _runCount) {
            setState(() => _state = _ReadingReport(page: page, totalPages: total,
                fileIndex: _currentFileIndex, totalFiles: _totalFiles));
          }
        },
      );
    } else {
      rawText = await _localOcr.extractTextFromImage(report.file);
    }

    if (!mounted || runId != _runCount) return null;

    final cleanedRaw = rawText.replaceAll(
      RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F\x7F\x80-\x9F]'),
      '',
    );

    if (cleanedRaw.trim().isEmpty) return null;

    // Phase 2: On-device redaction analysis
    final analysis = RedactionEngine.analyze(cleanedRaw);

    if (!mounted || runId != _runCount) return null;

    // Phase 2b: Practitioner review gate — fires on EVERY submission, no
    // skip affordance. This is the de-identification mechanism of record;
    // submitJob() cannot be called without the RedactionApproval this
    // screen produces.
    final approval = await Navigator.of(context).push<RedactionApproval>(
      MaterialPageRoute(
        settings: const RouteSettings(name: '/redaction-review'),
        builder: (_) => RedactionReviewScreen(analysis: analysis),
      ),
    );

    if (!mounted || runId != _runCount) return null;
    if (approval == null) return null; // practitioner cancelled/retook — treat like a failed file

    // Phase 3: Submit cleaned text
    if (mounted && runId == _runCount) {
      setState(() => _state = _Submitting(fileIndex: _currentFileIndex, totalFiles: _totalFiles));
    }

    final jobId = await _ocr.submitJob(
      approval: approval,
      documentType: report.isPdf ? 'pdf' : 'image',
      pageCount: 1,
    );

    if (!mounted || runId != _runCount) return null;

    // Phase 4: Poll for findings
    if (mounted && runId == _runCount) {
      setState(() => _state = _Polling(fileIndex: _currentFileIndex, totalFiles: _totalFiles));
    }

    await for (final job in _ocr.pollJob(jobId)) {
      if (!mounted || runId != _runCount) return null;
      if (job.status == OcrJobStatus.failed) {
        throw OcrServiceException(job.error ?? 'Processing failed.');
      }
      if (job.status == OcrJobStatus.completed) {
        return ExtractionResult.fromJson(job.result ?? {})
            .withTokens(job.tokensIn, job.tokensOut);
      }
    }
    return null;
  }

  int _currentFileIndex = 0;
  int _totalFiles = 1;

  Future<void> _run() async {
    final runId = _runCount;
    final batch = widget.effectiveBatch;
    _totalFiles = batch.length;

    try {
      if (batch.isSingle) {
        // Single file — original flow
        _currentFileIndex = 0;
        setState(() => _state = const _ReadingReport());

        final extraction = await _processOneReport(batch.first, runId);
        if (!mounted || runId != _runCount) return;

        if (extraction == null) {
          setState(() => _state = const _Failed(
            'Could not read text from this report. Please try a clearer image.',
          ));
          return;
        }

        await Navigator.of(context).push(
          MaterialPageRoute(
            settings: const RouteSettings(name: '/extract'),
            builder: (_) => ExtractScreen(extraction: extraction, patientMode: widget.patientMode),
          ),
        );
        if (mounted) Navigator.of(context).popUntil((r) => r.isFirst);
      } else {
        // Multi-file batch processing
        final results = <ExtractionResult>[];

        for (int i = 0; i < batch.length; i++) {
          if (!mounted || runId != _runCount) return;
          _currentFileIndex = i;
          setState(() => _state = _ReadingReport(
              fileIndex: i, totalFiles: batch.length));

          try {
            final extraction = await _processOneReport(batch.reports[i], runId);
            if (!mounted || runId != _runCount) return;
            if (extraction != null) {
              results.add(extraction);
            }
          } on OcrServiceException {
            // Skip failed files in batch mode, continue with remaining
            if (!mounted || runId != _runCount) return;
          }
        }

        if (!mounted || runId != _runCount) return;

        if (results.isEmpty) {
          setState(() => _state = const _Failed(
            'Could not read text from any of the selected files.',
          ));
          return;
        }

        final merged = ExtractionResult.merge(results);

        await Navigator.of(context).push(
          MaterialPageRoute(
            settings: const RouteSettings(name: '/extract'),
            builder: (_) => ExtractScreen(extraction: merged, patientMode: widget.patientMode),
          ),
        );
        if (mounted) Navigator.of(context).popUntil((r) => r.isFirst);
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
          title: const Text('Analyzing Report'),
          automaticallyImplyLeading: _state is _Failed,
        ),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: switch (_state) {
              _ReadingReport(page: final p, totalPages: final t, fileIndex: final fi, totalFiles: final tf) =>
                _ReadingReportView(page: p, totalPages: t, fileIndex: fi, totalFiles: tf, onStop: _stop),
              _Submitting(fileIndex: final fi, totalFiles: final tf) =>
                _SubmittingView(fileIndex: fi, totalFiles: tf, onStop: _stop),
              _Polling(fileIndex: final fi, totalFiles: final tf) =>
                _PollingView(fileIndex: fi, totalFiles: tf, onStop: _stop),
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
  final int? fileIndex;
  final int? totalFiles;
  const _ReadingReport({this.page, this.totalPages, this.fileIndex, this.totalFiles});
}

class _Submitting extends _ReaderState {
  final int? fileIndex;
  final int? totalFiles;
  const _Submitting({this.fileIndex, this.totalFiles});
}

class _Polling extends _ReaderState {
  final int? fileIndex;
  final int? totalFiles;
  const _Polling({this.fileIndex, this.totalFiles});
}

class _Failed extends _ReaderState {
  final String message;
  const _Failed(this.message);
}

// ── View widgets ──────────────────────────────────────────────────────────────

class _ReadingReportView extends StatelessWidget {
  final int? page;
  final int? totalPages;
  final int? fileIndex;
  final int? totalFiles;
  final VoidCallback onStop;

  const _ReadingReportView({this.page, this.totalPages, this.fileIndex, this.totalFiles, required this.onStop});

  @override
  Widget build(BuildContext context) {
    final bool isBatch = totalFiles != null && totalFiles! > 1;
    final fileLabel = isBatch ? 'File ${(fileIndex ?? 0) + 1} of $totalFiles' : null;
    final pageLabel = (page != null && totalPages != null)
        ? 'Reading page $page of $totalPages…'
        : 'Reading report…';

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Icon(Icons.document_scanner_outlined, size: 64, color: AppTheme.primary),
        const SizedBox(height: 24),
        if (fileLabel != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(fileLabel, textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AppTheme.gold)),
          ),
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
  final int? fileIndex;
  final int? totalFiles;
  final VoidCallback onStop;
  const _SubmittingView({this.fileIndex, this.totalFiles, required this.onStop});

  @override
  Widget build(BuildContext context) {
    final bool isBatch = totalFiles != null && totalFiles! > 1;
    final fileLabel = isBatch ? 'File ${(fileIndex ?? 0) + 1} of $totalFiles' : null;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Icon(Icons.biotech_outlined, size: 64, color: AppTheme.primary),
        const SizedBox(height: 24),
        if (fileLabel != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(fileLabel, textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AppTheme.gold)),
          ),
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
  final int? fileIndex;
  final int? totalFiles;
  final VoidCallback onStop;
  const _PollingView({this.fileIndex, this.totalFiles, required this.onStop});

  @override
  Widget build(BuildContext context) {
    final bool isBatch = totalFiles != null && totalFiles! > 1;
    final fileLabel = isBatch ? 'File ${(fileIndex ?? 0) + 1} of $totalFiles' : null;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Icon(Icons.shield_outlined, size: 64, color: AppTheme.primary),
        const SizedBox(height: 24),
        if (fileLabel != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(fileLabel, textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AppTheme.gold)),
          ),
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
