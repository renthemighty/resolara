import 'package:flutter/material.dart';
import '../../app/theme/app_theme.dart';
import '../../core/api/generation_service.dart';
import '../../core/models/extraction_result.dart';
import '../../core/models/generation_job.dart';
import '../../core/services/session_service.dart';
import '../../core/storage/app_database.dart';
import '../review/review_screen.dart';

class GenerateScreen extends StatefulWidget {
  final List<Finding> findings;
  /// Set when resuming a cached session — skips submission, polls directly.
  final String? resumeSessionId;
  final String? resumeVizJobId;
  /// Token counts from the extraction phase, stored in the session record.
  final int extractionTokensIn;
  final int extractionTokensOut;

  const GenerateScreen({
    super.key,
    required this.findings,
    this.resumeSessionId,
    this.resumeVizJobId,
    this.extractionTokensIn = 0,
    this.extractionTokensOut = 0,
  });

  @override
  State<GenerateScreen> createState() => _GenerateScreenState();
}

class _GenerateScreenState extends State<GenerateScreen> {
  final _service = GenerationService();
  _GenState _state = const _Submitting();
  late List<Finding> _currentFindings;
  late SessionService _sessions;
  String? _sessionId;
  int _runCount = 0;

  @override
  void initState() {
    super.initState();
    _currentFindings = List.of(widget.findings);
    _initSessions();
  }

  Future<void> _initSessions() async {
    final db = await openAppDatabase();
    _sessions = SessionService(db);

    if (widget.resumeSessionId != null && widget.resumeVizJobId != null) {
      // Resuming — skip submission, go straight to polling
      _sessionId = widget.resumeSessionId;
      setState(() => _state = const _Processing());
      _pollJob(widget.resumeVizJobId!, _runCount);
    } else {
      _run();
    }
  }

  Future<void> _run() async {
    final runId = _runCount;
    setState(() => _state = const _Submitting());
    try {
      // Create local session record
      _sessionId = await _sessions.createSession(
        findings: _currentFindings,
        tokensIn: widget.extractionTokensIn,
        tokensOut: widget.extractionTokensOut,
      );

      if (runId != _runCount) return;

      final jobId = await _service.submitGeneration(_currentFindings);
      await _sessions.setVizJobId(_sessionId!, jobId);

      if (runId != _runCount) return;

      setState(() => _state = const _Processing());
      _pollJob(jobId, runId);
    } on GenerationServiceException catch (e) {
      if (_sessionId != null) await _sessions.failSession(_sessionId!, e.message);
      if (mounted && runId == _runCount) setState(() => _state = _Failed(e.message));
    } catch (e) {
      final msg = 'An unexpected error occurred: $e';
      if (_sessionId != null) await _sessions.failSession(_sessionId!, msg);
      if (mounted && runId == _runCount) setState(() => _state = _Failed(msg));
    }
  }

  Future<void> _pollJob(String jobId, int runId) async {
    try {
      await for (final job in _service.pollJob(jobId)) {
        if (!mounted || runId != _runCount) return;
        if (job.status == GenerationJobStatus.failed) {
          final msg = job.error ?? 'Generation failed.';
          if (_sessionId != null) await _sessions.failSession(_sessionId!, msg);
          setState(() => _state = _Failed(msg));
          return;
        }
        if (job.status == GenerationJobStatus.completed) {
          if (_sessionId != null && job.imageUrl != null) {
            await _sessions.completeSession(_sessionId!, imageUrl: job.imageUrl!);
          }
          if (!mounted || runId != _runCount) return;
          final updated = await Navigator.of(context).push<List<Finding>>(
            MaterialPageRoute(
              builder: (_) => ReviewScreen(
                job: job,
                findings: _currentFindings,
              ),
            ),
          );
          if (updated != null && mounted) {
            _currentFindings = updated;
            _run();
          }
          return;
        }
      }
    } on GenerationServiceException catch (e) {
      if (_sessionId != null) await _sessions.failSession(_sessionId!, e.message);
      if (mounted && runId == _runCount) setState(() => _state = _Failed(e.message));
    } catch (e) {
      final msg = 'An unexpected error occurred: $e';
      if (_sessionId != null) await _sessions.failSession(_sessionId!, msg);
      if (mounted && runId == _runCount) setState(() => _state = _Failed(msg));
    }
  }

  void _stop() {
    if (_sessionId != null) {
      _sessions.failSession(_sessionId!, 'Stopped by user');
      _sessionId = null;
    }
    _runCount++;
    _run();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _state is _Failed,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Generating Visualization'),
          automaticallyImplyLeading: _state is _Failed,
          actions: [
            IconButton(
              icon: const Icon(Icons.home_outlined),
              tooltip: 'Home',
              onPressed: () {
                Navigator.of(context).popUntil((r) => r.isFirst);
              },
            ),
          ],
        ),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: switch (_state) {
              _Submitting() => _SubmittingView(onStop: _stop),
              _Processing() => _ProcessingView(onStop: _stop),
              _Failed(message: final msg) => _FailedView(
                  message: msg,
                  onRetry: _run,
                  onCancel: () => Navigator.of(context).pop(),
                ),
            },
          ),
        ),
      ),
    );
  }
}

// ── State types ───────────────────────────────────────────────────────────────

sealed class _GenState { const _GenState(); }
class _Submitting extends _GenState { const _Submitting(); }
class _Processing extends _GenState { const _Processing(); }
class _Failed extends _GenState {
  final String message;
  const _Failed(this.message);
}

// ── Views ─────────────────────────────────────────────────────────────────────

class _SubmittingView extends StatelessWidget {
  final VoidCallback onStop;
  const _SubmittingView({required this.onStop});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Icon(Icons.send_outlined, size: 64, color: AppTheme.accent),
        const SizedBox(height: 24),
        const Text('Creating structure…',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
        const SizedBox(height: 24),
        const LinearProgressIndicator(
          backgroundColor: Color(0x1AB7A46B),
          color: AppTheme.accent,
          minHeight: 8,
          borderRadius: BorderRadius.all(Radius.circular(4)),
        ),
        const SizedBox(height: 32),
        const _PrivacyNote(),
        const SizedBox(height: 24),
        _StopButton(onStop: onStop),
      ],
    );
  }
}

class _ProcessingView extends StatelessWidget {
  final VoidCallback onStop;
  const _ProcessingView({required this.onStop});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Icon(Icons.auto_awesome_outlined, size: 64, color: AppTheme.accent),
        const SizedBox(height: 24),
        const Text('Generating visualization…',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        const Text(
          'Creating an anatomical illustration based on the confirmed findings.',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppTheme.textSecondary),
        ),
        const SizedBox(height: 32),
        const LinearProgressIndicator(
          backgroundColor: Color(0x1AB7A46B),
          color: AppTheme.accent,
          minHeight: 8,
          borderRadius: BorderRadius.all(Radius.circular(4)),
        ),
        const SizedBox(height: 32),
        const _PrivacyNote(),
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
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppTheme.error.withAlpha(15),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.error.withAlpha(60)),
            ),
            child: const Column(
              children: [
                Icon(Icons.error_outline, size: 48, color: AppTheme.error),
                SizedBox(height: 16),
                Text(
                  'Generation failed',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                ),
                SizedBox(height: 8),
                Text(
                  'The visualization could not be created. This is usually temporary.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 14),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.surface.withAlpha(80),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.sage.withAlpha(60)),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('What to do',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textSecondary)),
                SizedBox(height: 10),
                _Tip(icon: Icons.refresh, text: 'Tap Try Again — most failures resolve on the first retry.'),
                SizedBox(height: 8),
                _Tip(icon: Icons.wifi_outlined, text: 'Check your internet connection if retries keep failing.'),
                SizedBox(height: 8),
                _Tip(icon: Icons.arrow_back_outlined, text: 'Go Back to edit the findings and try with fewer regions.'),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              color: AppTheme.surface.withAlpha(40),
            ),
            child: Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh, size: 18),
            label: const Text('Try Again'),
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: onCancel,
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(double.infinity, 56),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Go Back'),
          ),
        ],
      ),
    );
  }
}

class _Tip extends StatelessWidget {
  final IconData icon;
  final String text;
  const _Tip({required this.icon, required this.text});
  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 15, color: AppTheme.accent),
        const SizedBox(width: 8),
        Expanded(
          child: Text(text,
              style: const TextStyle(
                  fontSize: 13, color: AppTheme.textSecondary)),
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
        Text(
          'Generated using de-identified findings only.',
          style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
        ),
      ],
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
      child: const Text('Stop & Restart'),
    );
  }
}
