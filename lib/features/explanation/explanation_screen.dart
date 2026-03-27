import 'package:flutter/material.dart';
import '../../app/theme/app_theme.dart';
import '../../core/api/explanation_service.dart';
import '../../core/models/explanation.dart';
import '../../core/models/extraction_result.dart';

class ExplanationScreen extends StatefulWidget {
  final List<Finding> findings;

  const ExplanationScreen({super.key, required this.findings});

  @override
  State<ExplanationScreen> createState() => _ExplanationScreenState();
}

class _ExplanationScreenState extends State<ExplanationScreen> {
  final _service = ExplanationService();
  List<FindingExplanation> _explanations = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final results = await _service.fetchExplanations(widget.findings);
      setState(() { _explanations = results; _loading = false; });
    } on ExplanationServiceException catch (e) {
      setState(() { _error = e.message; _loading = false; });
    } catch (_) {
      setState(() { _error = 'Could not load explanations.'; _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Injury Explanation'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: _loading
          ? const _LoadingView()
          : _error != null
              ? _ErrorView(message: _error!, onRetry: _load)
              : Column(
                  children: [
                    Expanded(
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                        children: [
                          const Padding(
                            padding: EdgeInsets.only(bottom: 16, left: 2),
                            child: Text(
                              'Plain-language breakdown of each confirmed finding.',
                              style: TextStyle(
                                  fontSize: 13,
                                  color: AppTheme.textSecondary),
                            ),
                          ),
                          ..._explanations.map(
                            (e) => Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: _ExplanationCard(explanation: e),
                            ),
                          ),
                          const SizedBox(height: 8),
                        ],
                      ),
                    ),
                    _ConfirmBar(
                      onConfirm: () => Navigator.of(context).pop(true),
                    ),
                  ],
                ),
    );
  }
}

// ── Explanation card ──────────────────────────────────────────────────────────

class _ExplanationCard extends StatefulWidget {
  final FindingExplanation explanation;
  const _ExplanationCard({required this.explanation});

  @override
  State<_ExplanationCard> createState() => _ExplanationCardState();
}

class _ExplanationCardState extends State<_ExplanationCard> {
  bool _expanded = true;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? AppTheme.warmStone : AppTheme.emerald;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFF1E4535) : AppTheme.sage,
          width: 1,
        ),
        color: isDark ? const Color(0xFF122B21) : AppTheme.lightSurface,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header — always visible
          GestureDetector(
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.explanation.heading,
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: textColor),
                    ),
                  ),
                  Icon(
                    _expanded
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    color: AppTheme.textSecondary,
                    size: 20,
                  ),
                ],
              ),
            ),
          ),

          // Expanded body
          if (_expanded) ...[
            const Divider(height: 1, color: Color(0x20FFFFFF)),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _Section(
                    label: 'What it is',
                    text:  widget.explanation.whatItIs,
                    isDark: isDark,
                  ),
                  const SizedBox(height: 14),
                  _Section(
                    label: 'Why it matters',
                    text:  widget.explanation.whyItMatters,
                    isDark: isDark,
                  ),
                  const SizedBox(height: 14),
                  _Section(
                    label: 'Typical outlook',
                    text:  widget.explanation.outlook,
                    isDark: isDark,
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String label;
  final String text;
  final bool isDark;

  const _Section({
    required this.label,
    required this.text,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: AppTheme.gold,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          text,
          style: TextStyle(
            fontSize: 14,
            height: 1.5,
            color: isDark
                ? AppTheme.warmStone.withAlpha(220)
                : AppTheme.emerald.withAlpha(220),
          ),
        ),
      ],
    );
  }
}

// ── Confirm bar ───────────────────────────────────────────────────────────────

class _ConfirmBar extends StatelessWidget {
  final VoidCallback onConfirm;
  const _ConfirmBar({required this.onConfirm});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppTheme.surface,
        border: Border(top: BorderSide(color: AppTheme.sage, width: 0.5)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
      child: ElevatedButton(
        onPressed: onConfirm,
        child: const Text('Done'),
      ),
    );
  }
}

// ── Loading / error ───────────────────────────────────────────────────────────

class _LoadingView extends StatelessWidget {
  const _LoadingView();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(color: AppTheme.gold),
          SizedBox(height: 20),
          Text('Generating explanations…',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 14)),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: AppTheme.error),
            const SizedBox(height: 16),
            Text(message,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppTheme.textSecondary)),
            const SizedBox(height: 24),
            ElevatedButton(onPressed: onRetry, child: const Text('Try Again')),
          ],
        ),
      ),
    );
  }
}
