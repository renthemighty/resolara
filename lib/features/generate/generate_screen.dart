import 'package:flutter/material.dart';
import '../../app/theme/app_theme.dart';
import '../../core/api/generation_service.dart';
import '../../core/models/extraction_result.dart';
import '../../core/services/analytics_service.dart';
import '../../core/services/session_service.dart';
import '../../core/storage/app_database.dart';
import '../review/review_screen.dart';

class GenerateScreen extends StatefulWidget {
  final List<Finding> findings;
  /// If set, bypasses the findings pipeline and sends a direct text prompt.
  final String? directPrompt;
  final String patientName;
  /// Set when resuming a cached session — skips submission, polls directly.
  final String? resumeSessionId;
  final String? resumeVizJobId;
  /// Token counts from the extraction phase, stored in the session record.
  final int extractionTokensIn;
  final int extractionTokensOut;

  const GenerateScreen({
    super.key,
    this.findings = const [],
    this.directPrompt,
    this.patientName = '',
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
  SessionService? _sessions;
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
      // Resuming — push ReviewScreen directly; it will poll the in-progress job.
      _sessionId = widget.resumeSessionId;
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) return;
        final updated = await Navigator.of(context).push<List<Finding>>(
          MaterialPageRoute(
            builder: (_) => ReviewScreen(
              pendingJobId: widget.resumeVizJobId!,
              sessionId: _sessionId,
              findings: _currentFindings,
              patientName: widget.patientName,
            ),
          ),
        );
        if (updated != null && mounted) {
          _currentFindings = updated;
          _run();
        }
      });
    } else {
      _run();
    }
  }

  Future<void> _run() async {
    if (_sessions == null) return; // _initSessions will call _run() once ready
    final runId = _runCount;
    setState(() => _state = const _Submitting());
    try {
      // Create local session record
      _sessionId = await _sessions!.createSession(
        findings: _currentFindings,
        tokensIn: widget.extractionTokensIn,
        tokensOut: widget.extractionTokensOut,
      );

      if (runId != _runCount) return;

      Analytics.generationRequested();
      final jobId = widget.directPrompt != null
          ? await _service.submitDirectPrompt(widget.directPrompt!, patientName: widget.patientName)
          : await _service.submitGeneration(_currentFindings, patientName: widget.patientName);
      await _sessions!.setVizJobId(_sessionId!, jobId);

      if (runId != _runCount || !mounted) return;

      // Push ReviewScreen immediately — it polls the job and loads the image itself.
      final updated = await Navigator.of(context).push<List<Finding>>(
        MaterialPageRoute(
          builder: (_) => ReviewScreen(
            pendingJobId: jobId,
            sessionId: _sessionId,
            findings: _currentFindings,
            patientName: widget.patientName,
          ),
        ),
      );
      if (updated != null && mounted) {
        _currentFindings = updated;
        _run();
      }
    } on GenerationServiceException catch (e) {
      if (_sessionId != null) await _sessions?.failSession(_sessionId!, e.message);
      if (mounted && runId == _runCount) setState(() => _state = _Failed(e.message));
    } catch (e) {
      final msg = 'An unexpected error occurred: $e';
      if (_sessionId != null) await _sessions?.failSession(_sessionId!, msg);
      if (mounted && runId == _runCount) setState(() => _state = _Failed(msg));
    }
  }

  void _stop() {
    if (_sessionId != null) {
      _sessions?.failSession(_sessionId!, 'Stopped by user');
      _sessionId = null;
    }
    _runCount++;
    Navigator.of(context).popUntil((r) => r.isFirst);
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor = Theme.of(context).colorScheme.surface;
    final onSurfaceColor = Theme.of(context).colorScheme.onSurface;

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
            child: Column(
              children: [
                const Icon(Icons.error_outline, size: 48, color: AppTheme.error),
                const SizedBox(height: 16),
                Text(
                  'Generation failed',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: onSurfaceColor),
                ),
                const SizedBox(height: 8),
                Text(
                  'The visualization could not be created. This is usually temporary.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: onSurfaceColor.withAlpha(160), fontSize: 14),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: surfaceColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.sage.withAlpha(isDark ? 60 : 120)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('What to do',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: onSurfaceColor.withAlpha(180))),
                const SizedBox(height: 10),
                _Tip(icon: Icons.refresh, text: 'Tap Try Again — most failures resolve on the first retry.', color: onSurfaceColor),
                const SizedBox(height: 8),
                _Tip(icon: Icons.wifi_outlined, text: 'Check your internet connection if retries keep failing.', color: onSurfaceColor),
                const SizedBox(height: 8),
                _Tip(icon: Icons.arrow_back_outlined, text: 'Go Back to edit the findings and try with fewer regions.', color: onSurfaceColor),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              color: surfaceColor,
            ),
            child: Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11, color: onSurfaceColor.withAlpha(160)),
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
  final Color color;
  const _Tip({required this.icon, required this.text, required this.color});
  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 15, color: AppTheme.accent),
        const SizedBox(width: 8),
        Expanded(
          child: Text(text,
              style: TextStyle(fontSize: 13, color: color.withAlpha(200))),
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
      child: const Text('Cancel'),
    );
  }
}
