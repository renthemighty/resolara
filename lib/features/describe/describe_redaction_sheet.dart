import 'package:flutter/material.dart';
import '../../app/theme/app_theme.dart';
import '../../core/services/redaction/redaction.dart';

/// Confirmation gate for the "Describe Instead" free text path.
///
/// This is the exact point where a practitioner types or dictates raw
/// identifiers, so it enforces the same safety properties as the OCR path's
/// full review screen ([lib/features/redaction/redaction_review_screen.dart]),
/// just in a lighter bottom-sheet shell since this text is short and
/// self-authored:
///  - deterministic spans (dates, MRNs, emails, etc.) are pre-redacted, but
///    lower-confidence spans start `pending` and the practitioner must
///    actively resolve (redact or keep) every one of them before Send
///    unlocks — no one-tap accept-all.
///  - when the engine finds nothing, Send is disabled until the
///    practitioner ticks an explicit "I confirm this contains no
///    patient-identifying information" attestation.
/// Returns the practitioner-approved [RedactionAnalysis] on confirm, or
/// `null` if they back out to keep editing.
class DescribeRedactionSheet extends StatefulWidget {
  final RedactionAnalysis analysis;
  const DescribeRedactionSheet({super.key, required this.analysis});

  /// Shows the sheet and returns the resolved [RedactionAnalysis] if the
  /// practitioner confirms sending, or `null` if they cancel to keep editing.
  static Future<RedactionAnalysis?> show(
    BuildContext context,
    RedactionAnalysis analysis,
  ) {
    return showModalBottomSheet<RedactionAnalysis>(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => DescribeRedactionSheet(analysis: analysis),
    );
  }

  @override
  State<DescribeRedactionSheet> createState() => _DescribeRedactionSheetState();
}

class _DescribeRedactionSheetState extends State<DescribeRedactionSheet> {
  bool _attested = false;

  @override
  void initState() {
    super.initState();
    // Deterministic spans are pre-redacted by default — the practitioner
    // only has to actively resolve the lower-confidence likely/candidate
    // spans (mirrors the OCR review screen's discipline). Tapping a
    // deterministic chip can still restore it.
    for (final s in widget.analysis.spans) {
      if (s.confidence == SpanConfidence.deterministic &&
          s.decision == SpanDecision.pending) {
        s.decision = SpanDecision.accepted;
      }
    }
  }

  bool get _isZeroFindings => widget.analysis.spans.isEmpty;

  /// Nothing can be sent until every span has been actively resolved and,
  /// in the zero-findings case, the practitioner has attested to reading
  /// the full text.
  bool get _canSend => _blockReasons.isEmpty;

  /// Reasons Send is currently blocked, surfaced via SnackBar on tap so a
  /// disabled button never fails silently. See redaction_review_screen.dart
  /// for the same pattern on the full OCR review gate.
  List<String> get _blockReasons {
    final reasons = <String>[];
    final pendingCount = widget.analysis.spans
        .where((s) => s.decision == SpanDecision.pending)
        .length;
    if (pendingCount > 0) {
      reasons.add('Resolve the $pendingCount item${pendingCount == 1 ? '' : 's'} '
          'above');
    }
    if (_isZeroFindings && !_attested) {
      reasons.add('Confirm the attestation checkbox');
    }
    return reasons;
  }

  void _handleSendTap() {
    final reasons = _blockReasons;
    if (reasons.isNotEmpty) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(reasons.join(' · '))));
      return;
    }
    Navigator.of(context).pop(widget.analysis);
  }

  void _toggle(RedactionSpan span) {
    setState(() {
      // From pending or dismissed, a tap redacts (resolves the span);
      // from accepted, a tap restores the original text.
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
    final pendingCount = spans.where((s) => s.decision == SpanDecision.pending).length;
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
                  Expanded(
                    child: Text(
                      _isZeroFindings
                          ? 'Nothing detected to redact'
                          : pendingCount > 0
                              ? '$pendingCount item${pendingCount == 1 ? '' : 's'} need${pendingCount == 1 ? 's' : ''} your review'
                              : 'Review before sending',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                _isZeroFindings
                    ? 'No identifiers were detected in this text, but automatic detection is not guaranteed. '
                        'Read it carefully — if it still contains a name, date of birth, or other identifying '
                        'detail, go back and edit before sending.'
                    : '${widget.analysis.buildSummary()} will be removed before this is sent to our servers.',
                style: TextStyle(fontSize: 13, color: onSurface.withOpacity(0.7)),
              ),
              if (_isZeroFindings) ...[
                const SizedBox(height: 12),
                _AttestationCheckbox(
                  value: _attested,
                  onChanged: (v) => setState(() => _attested = v),
                ),
              ],
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
                // Stays tappable even when blocked — see _handleSendTap:
                // a disabled button here would swallow the tap with no
                // explanation of which precondition is unmet.
                onPressed: _handleSendTap,
                style: _canSend
                    ? null
                    : ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.sage.withAlpha(90),
                        foregroundColor: AppTheme.textSecondary,
                      ),
                icon: const Icon(Icons.send_outlined, size: 18),
                label: Text(_isZeroFindings ? 'Send unredacted text' : 'Send redacted text'),
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
    final pending = span.decision == SpanDecision.pending;
    final accepted = span.decision == SpanDecision.accepted;
    final onSurface = Theme.of(context).colorScheme.onSurface;

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onToggle,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            decoration: pending
                ? BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppTheme.gold, width: 1),
                  )
                : null,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Row(
              children: [
                Icon(
                  pending
                      ? Icons.priority_high_rounded
                      : accepted
                          ? Icons.check_box
                          : Icons.check_box_outline_blank,
                  size: 20,
                  color: pending
                      ? AppTheme.gold
                      : accepted
                          ? AppTheme.gold
                          : onSurface.withOpacity(0.4),
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
                  pending ? 'Tap to resolve' : (accepted ? 'Redact' : 'Keep'),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: pending
                        ? AppTheme.gold
                        : accepted
                            ? AppTheme.gold
                            : onSurface.withOpacity(0.5),
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

class _AttestationCheckbox extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;
  const _AttestationCheckbox({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => onChanged(!value),
      borderRadius: BorderRadius.circular(12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Checkbox(
            value: value,
            onChanged: (v) => onChanged(v ?? false),
            activeColor: AppTheme.emerald,
          ),
          const Expanded(
            child: Padding(
              padding: EdgeInsets.only(top: 12),
              child: Text(
                'I confirm this contains no patient-identifying information.',
                style: TextStyle(fontSize: 13),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
