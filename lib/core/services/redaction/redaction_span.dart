/// Confidence tier for a detected span.
///
/// Ordering matters: it doubles as the overlap-resolution priority
/// (deterministic > likely > candidate). See [RedactionEngine] for the
/// resolution algorithm.
enum SpanConfidence {
  /// Regex/format is genuinely reliable on its own (dates, emails, phone
  /// numbers, labelled IDs, validated SIN/SSN, etc.).
  deterministic,

  /// Strong signal but not airtight (e.g. "Dr. Smith" — the title is a
  /// real label, but title-cased words can still be wrong).
  likely,

  /// Heuristic guess offered for human review. Expected to contain false
  /// positives — that is by design: recall over precision, because a
  /// practitioner reviews every span before submission.
  candidate,
}

/// Which detector produced a span. Useful for the review UI (e.g. to group
/// or explain why something was flagged) and for debugging.
enum SpanSource { regex, gazetteer, headerZone, bigram, clinicList, manual }

/// Practitioner disposition for a span. Every span starts `pending`; the
/// review screen is expected to resolve all of them before submission.
enum SpanDecision { pending, accepted, dismissed }

/// A single detected candidate-identifier span over the original text.
///
/// [start]/[end] are char offsets into `RedactionAnalysis.originalText`
/// (end-exclusive, i.e. `originalText.substring(start, end) == originalText`
/// slice matching [originalText] field content at detection time).
class RedactionSpan {
  final int start;
  final int end;

  /// One of: NAME, DATE, MRN, POSTAL, PHONE, EMAIL, ADDRESS, HEALTH_ID,
  /// SSN, ACCOUNT, LICENCE, DEVICE_ID, URL, IP, AGE_90_PLUS, PROVIDER,
  /// FACILITY, OTHER_ID.
  final String category;

  /// Indexed placeholder, e.g. `[NAME_1]`. The same original value (same
  /// category, case-insensitively-normalized text) always maps to the same
  /// placeholder within one [RedactionAnalysis], so coreference survives
  /// redaction for downstream LLM extraction.
  final String placeholder;

  final SpanConfidence confidence;
  final SpanSource source;

  /// The exact matched substring, kept for display in the review UI.
  final String originalText;

  /// Mutable — set by the practitioner-review screen.
  SpanDecision decision;

  RedactionSpan({
    required this.start,
    required this.end,
    required this.category,
    required this.placeholder,
    required this.confidence,
    required this.source,
    required this.originalText,
    this.decision = SpanDecision.pending,
  });

  @override
  String toString() =>
      'RedactionSpan($category "$originalText" [$start,$end) '
      '$confidence/$source -> $placeholder, $decision)';
}
