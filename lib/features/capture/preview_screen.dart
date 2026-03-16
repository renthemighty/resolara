import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/models/captured_report.dart';
import '../../app/theme/app_theme.dart';
import '../../shared/widgets/loading_overlay.dart';
import '../../shared/widgets/error_view.dart';

class PreviewScreen extends StatefulWidget {
  final CapturedReport report;

  const PreviewScreen({super.key, required this.report});

  @override
  State<PreviewScreen> createState() => _PreviewScreenState();
}

class _PreviewScreenState extends State<PreviewScreen> {
  bool _submitting = false;
  String? _error;

  Future<void> _confirm() async {
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      // TODO: navigate to reader/OCR screen (Step C), passing the report
      // context.go('/reader', extra: widget.report);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('OCR submission coming in Step C.')),
        );
        context.go('/home');
      }
    } catch (e) {
      setState(() => _error = 'Something went wrong. Please try again.');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Scaffold(
          appBar: AppBar(
            title: const Text('Review Image'),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => context.go('/home'),
            ),
          ),
          body: _error != null
              ? ErrorView(message: _error!, onRetry: _confirm)
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: Container(
                        color: Colors.black,
                        child: Image.file(
                          widget.report.file,
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                    _InfoBanner(report: widget.report),
                    Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          ElevatedButton(
                            onPressed: _submitting ? null : _confirm,
                            child: const Text('Use This Image'),
                          ),
                          const SizedBox(height: 12),
                          OutlinedButton(
                            onPressed:
                                _submitting ? null : () => context.go('/home'),
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size(double.infinity, 56),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                            ),
                            child: const Text('Retake / Choose Different'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
        ),
        if (_submitting) const LoadingOverlay(message: 'Preparing report…'),
      ],
    );
  }
}

class _InfoBanner extends StatelessWidget {
  final CapturedReport report;

  const _InfoBanner({required this.report});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppTheme.primary.withAlpha(20),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          const Icon(Icons.shield_outlined, size: 16, color: AppTheme.primary),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              'Metadata removed. Image will be de-identified before analysis.',
              style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}
