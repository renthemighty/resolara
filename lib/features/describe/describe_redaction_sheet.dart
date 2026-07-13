import 'package:flutter/material.dart';
import '../../app/theme/app_theme.dart';
import '../../core/services/redaction/redaction.dart';

/// Lightweight in-screen confirmation gate for the "Describe Instead" free
/// text path.
///
/// Unlike the OCR path (which uses a full review screen), the practitioner
/// just typed or dictated this text themselves, so a bottom sheet is enough:
/// it shows what will be redacted, lets the practitioner dismiss any
/// detected span that isn't actually an identifier, and previews the exact
/// text that will be sent. Returns the practitioner-approved [RedactionAnalysis]
/// on confirm, or `null` if they back out to keep editing.
class DescribeRedactionSheet extends StatefulWidget {
  final RedactionAnalysis analysis;
  const DescribeRedactionSheet({super.key, required this.analysis});

  /// Shows the sheet. All spans start accepted (matching "redact by
  /// default"); the practitioner can dismiss individual false positives.
  /// Returns the resolved [RedactionAnalysis] if the practitioner confirms
  /// sending, or `null` if they cancel to keep editing.
  static Future<RedactionAnalysis?> show(
    BuildContext context,
    RedactionAnalysis analysis,
  ) {
    for (final span in analysis.spans) {
      span.decision = SpanDecision.accepted;
    }
    return showModalBottomSheet<RedactionAnalysis>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => DescribeRedactionSheet(analysis: analysis),
    );
  }

  @override
  State<DescribeRedactionSheet> createState() => _DescribeRedactionSheetState();
}

class _DescribeRedactionSheetState extends State<DescribeRedactionSheet> {
  void _toggle(RedactionSpan span) {
    setState(() {
      span.decision = span.decision == SpanDecision.accepted
          ? SpanDecision.dismissed
          : SpanDecision.accepted;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final spans = widget.analysis.spans;
    final acceptedCount = spans.where((s) => s.decision == SpanDecision.accepted).length;
    final preview = widget.analysis.buildRedactedText();

    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Icon(Icons.shield_outlined, color: AppTheme.gold, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    acceptedCount > 0
                        ? 'Review before sending'
                        : 'Nothing detected to redact',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                acceptedCount > 0
                    ? '${widget.analysis.buildSummary()} will be removed before this is sent to our servers.'
                    : 'No identifiers were detected in this text, but automatic detection is not guaranteed. '
                        'Go back and edit if it still contains a name, date of birth, or other identifying detail.',
                style: TextStyle(fontSize: 13, color: onSurface.withOpacity(0.7)),
              ),
              if (spans.isNotEmpty) ...[
                const SizedBox(height: 16),
                ...spans.map((span) => _SpanTile(
                      span: span,
                      onToggle: () => _toggle(span),
                    )),
              ],
              const SizedBox(height: 16),
              Text(
                'PREVIEW — WHAT WILL BE SENT',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.6,
                  color: onSurface.withOpacity(0.5),
                ),
              ),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark ? AppTheme.surface : AppTheme.lightSurface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppTheme.sage.withAlpha(isDark ? 60 : 120)),
                ),
                child: Text(
                  preview,
                  style: TextStyle(fontSize: 13, height: 1.4, color: onSurface.withOpacity(0.85)),
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: () => Navigator.of(context).pop(widget.analysis),
                icon: const Icon(Icons.send_outlined, size: 18),
                label: const Text('Send redacted text'),
              ),
              const SizedBox(height: 10),
              OutlinedButton(
                onPressed: () => Navigator.of(context).pop(null),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 48),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Go back and edit'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SpanTile extends StatelessWidget {
  final RedactionSpan span;
  final VoidCallback onToggle;
  const _SpanTile({required this.span, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    final accepted = span.decision == SpanDecision.accepted;
    final onSurface = Theme.of(context).colorScheme.onSurface;

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onToggle,
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Row(
              children: [
                Icon(
                  accepted ? Icons.check_box : Icons.check_box_outline_blank,
                  size: 20,
                  color: accepted ? AppTheme.gold : onSurface.withOpacity(0.4),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        span.originalText,
                        style: TextStyle(
                          fontSize: 14,
                          decoration: accepted ? null : TextDecoration.lineThrough,
                          color: accepted ? onSurface : onSurface.withOpacity(0.5),
                        ),
                      ),
                      Text(
                        span.category,
                        style: TextStyle(fontSize: 11, color: onSurface.withOpacity(0.5)),
                      ),
                    ],
                  ),
                ),
                Text(
                  accepted ? 'Redact' : 'Keep',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: accepted ? AppTheme.gold : onSurface.withOpacity(0.5),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
