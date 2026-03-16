import 'package:flutter/material.dart';
import '../../app/theme/app_theme.dart';
import '../../core/api/generation_service.dart';
import '../../core/models/extraction_result.dart';
import '../../core/models/generation_job.dart';
import '../review/review_screen.dart';

class GenerateScreen extends StatefulWidget {
  final List<Finding> findings;

  const GenerateScreen({super.key, required this.findings});

  @override
  State<GenerateScreen> createState() => _GenerateScreenState();
}

class _GenerateScreenState extends State<GenerateScreen> {
  final _service = GenerationService();
  _GenState _state = const _Submitting();

  @override
  void initState() {
    super.initState();
    _run();
  }

  Future<void> _run() async {
    setState(() => _state = const _Submitting());
    try {
      final jobId = await _service.submitGeneration(widget.findings);
      setState(() => _state = const _Processing());

      await for (final job in _service.pollJob(jobId)) {
        if (!mounted) return;
        if (job.status == GenerationJobStatus.failed) {
          setState(() => _state = _Failed(job.error ?? 'Generation failed.'));
          return;
        }
        if (job.status == GenerationJobStatus.completed) {
          if (!mounted) return;
          await Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => ReviewScreen(job: job),
            ),
          );
          return;
        }
      }
    } on GenerationServiceException catch (e) {
      if (mounted) setState(() => _state = _Failed(e.message));
    } catch (_) {
      if (mounted) {
        setState(() => const _Failed('An unexpected error occurred.'));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _state is _Failed,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Generating Visualization'),
          automaticallyImplyLeading: _state is _Failed,
        ),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: switch (_state) {
              _Submitting() => const _SubmittingView(),
              _Processing() => const _ProcessingView(),
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

sealed class _GenState {
  const _GenState();
}

class _Submitting extends _GenState {
  const _Submitting();
}

class _Processing extends _GenState {
  const _Processing();
}

class _Failed extends _GenState {
  final String message;
  const _Failed(this.message);
}

// ── Views ─────────────────────────────────────────────────────────────────────

class _SubmittingView extends StatelessWidget {
  const _SubmittingView();

  @override
  Widget build(BuildContext context) {
    return const Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Icon(Icons.send_outlined, size: 64, color: AppTheme.accent),
        SizedBox(height: 24),
        Text('Sending findings…',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
        SizedBox(height: 24),
        LinearProgressIndicator(
          backgroundColor: Color(0x1AB7A46B),
          color: AppTheme.accent,
          minHeight: 8,
          borderRadius: BorderRadius.all(Radius.circular(4)),
        ),
        SizedBox(height: 32),
        _PrivacyNote(),
      ],
    );
  }
}

class _ProcessingView extends StatelessWidget {
  const _ProcessingView();

  @override
  Widget build(BuildContext context) {
    return const Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Icon(Icons.auto_awesome_outlined, size: 64, color: AppTheme.accent),
        SizedBox(height: 24),
        Text('Generating visualization…',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
        SizedBox(height: 8),
        Text(
          'Creating an anatomical illustration based on the confirmed findings.',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppTheme.textSecondary),
        ),
        SizedBox(height: 32),
        LinearProgressIndicator(
          backgroundColor: Color(0x1AB7A46B),
          color: AppTheme.accent,
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
        const Text('Generation failed',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Text(message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppTheme.textSecondary)),
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
          child: const Text('Go Back'),
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
