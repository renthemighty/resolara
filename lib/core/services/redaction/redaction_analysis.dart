import 'redaction_span.dart';

/// Coarse risk signal for the review screen to badge the report with.
///
/// - [high]: nothing was found at all (suspicious for a real clinical
///   report — probably means the detectors missed something), OR there is
///   at least one still-pending low-confidence NAME candidate outstanding.
/// - [elevated]: some other span is still pending review.
/// - [normal]: every span has been resolved (accepted or dismissed).
enum RiskLevel { normal, elevated, high }

/// Human-readable, pluralized labels for `buildSummary()`.
const Map<String, String> _categoryLabels = {
  'NAME': 'name',
  'DATE': 'date',
  'MRN': 'medical record number',
  'POSTAL': 'postal/zip code',
  'PHONE': 'phone number',
  'EMAIL': 'email address',
  'ADDRESS': 'address',
  'HEALTH_ID': 'health card number',
  'SSN': 'SSN/SIN',
  'ACCOUNT': 'account number',
  'LICENCE': 'licence number',
  'DEVICE_ID': 'device ID',
  'URL': 'URL',
  'IP': 'IP address',
  'AGE_90_PLUS': 'age',
  'PROVIDER': 'provider name',
  'FACILITY': 'facility name',
  'OTHER_ID': 'ID number',
};

String _pluralize(String label, int count) {
  if (count == 1) return label;
  if (label.endsWith('s')) return label; // "SSN/SIN" etc, leave as-is
  return '${label}s';
}

/// Result of running [RedactionEngine.analyze] over a report.
///
/// This is a *span model*, not a redacted string: the review screen renders
/// [spans] over [originalText], lets the practitioner accept/dismiss each
/// one, and only then calls [buildRedactedText] to produce the text that is
/// actually sent to the server.
class RedactionAnalysis {
  final String originalText;
  final List<RedactionSpan> spans;

  RedactionAnalysis({required this.originalText, required this.spans});

  RiskLevel get risk {
    if (spans.isEmpty) return RiskLevel.high;

    final hasPendingCandidateName = spans.any(
      (s) =>
          s.decision == SpanDecision.pending &&
          s.confidence == SpanConfidence.candidate &&
          s.category == 'NAME',
    );
    if (hasPendingCandidateName) return RiskLevel.high;

    final hasPending = spans.any((s) => s.decision == SpanDecision.pending);
    if (hasPending) return RiskLevel.elevated;

    return RiskLevel.normal;
  }

  bool get readyToSubmit =>
      spans.every((s) => s.decision != SpanDecision.pending);

  /// Applies ACCEPTED spans only, replacing each with its placeholder.
  ///
  /// Built by walking spans sorted by [RedactionSpan.start] with a
  /// [StringBuffer] so offsets stay correct regardless of how many
  /// replacements are made or how their lengths differ from the originals —
  /// sequential `String.replaceAll` calls (the old engine's approach) drift
  /// as soon as more than one span is applied.
  String buildRedactedText() {
    final accepted =
        spans.where((s) => s.decision == SpanDecision.accepted).toList()
          ..sort((a, b) => a.start.compareTo(b.start));

    final buf = StringBuffer();
    var cursor = 0;
    for (final s in accepted) {
      if (s.start < cursor) {
        // Defensive: spans should never overlap post-resolution, but never
        // let a corrupt/overlapping span corrupt the output.
        continue;
      }
      buf.write(originalText.substring(cursor, s.start));
      buf.write(s.placeholder);
      cursor = s.end;
    }
    buf.write(originalText.substring(cursor));
    return buf.toString();
  }

  Map<String, int> get acceptedCountsByCategory {
    final counts = <String, int>{};
    for (final s in spans) {
      if (s.decision == SpanDecision.accepted) {
        counts[s.category] = (counts[s.category] ?? 0) + 1;
      }
    }
    return counts;
  }

  String buildSummary() {
    final counts = acceptedCountsByCategory;
    if (counts.isEmpty) return 'No identifying information redacted.';
    final parts = counts.entries.map((e) {
      final label = _pluralize(_categoryLabels[e.key] ?? e.key.toLowerCase(), e.value);
      return '${e.value} $label';
    }).toList();
    return '${parts.join(', ')} redacted';
  }
}
