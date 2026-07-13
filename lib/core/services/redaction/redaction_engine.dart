import 'clinic_identifiers.dart';
import 'detectors.dart' as detectors;
import 'raw_span.dart';
import 'redaction_analysis.dart';
import 'redaction_span.dart';

/// De-identification engine: turns raw OCR'd report text into a
/// [RedactionAnalysis] span model for practitioner review.
///
/// This deliberately does NOT claim to guarantee HIPAA Safe Harbor by
/// itself — free-text regex detection cannot. Its job is high-recall
/// candidate generation; the practitioner reviewing every span is the
/// de-identification mechanism of record. Lower-confidence detectors are
/// intentionally noisy: a dismissed false positive costs a tap, a missed
/// true positive is a PHI breach.
class RedactionEngine {
  RedactionEngine._();

  static RedactionAnalysis analyze(String rawText, {ClinicIdentifiers? clinic}) {
    final raw = <RawSpan>[];

    // Deterministic detectors first (also sets tie-break priority for
    // exact-duplicate-range dedup below, e.g. SIN-before-ULI).
    raw.addAll(detectors.detectDates(rawText));
    raw.addAll(detectors.detectPhones(rawText));
    raw.addAll(detectors.detectEmails(rawText));
    raw.addAll(detectors.detectUrls(rawText));
    raw.addAll(detectors.detectIps(rawText));
    raw.addAll(detectors.detectSsnSin(rawText));
    raw.addAll(detectors.detectPostal(rawText));
    raw.addAll(detectors.detectAge90Plus(rawText));
    raw.addAll(detectors.detectLabelledIds(rawText));
    raw.addAll(detectors.detectHealthId(rawText));
    raw.addAll(detectors.detectAddress(rawText));
    if (clinic != null && !clinic.isEmpty) {
      raw.addAll(detectors.detectClinicIdentifiers(rawText, clinic));
    }

    // Likely.
    raw.addAll(detectors.detectProvider(rawText));
    raw.addAll(detectors.detectNameTitle(rawText));

    // Candidate.
    raw.addAll(detectors.detectNameHeaderZone(rawText));
    raw.addAll(detectors.detectNameBigram(rawText));
    raw.addAll(detectors.detectOtherId(rawText));

    final deduped = _dedupeExactRanges(raw);
    final resolved = _resolveOverlaps(deduped)
      ..sort((a, b) => a.start.compareTo(b.start));

    final spans = _assignPlaceholders(resolved);
    return RedactionAnalysis(originalText: rawText, spans: spans);
  }

  /// Two detectors can legitimately fire on the exact same [start,end)
  /// range (e.g. an unformatted 9-digit run matches both the Luhn-validated
  /// SIN detector and the bare-9-digit Alberta ULI detector). Overlap
  /// resolution alone can't break that tie deterministically since
  /// confidence and length are equal, so collapse exact-range duplicates
  /// first, keeping whichever detector ran first (see ordering in
  /// [analyze]).
  static List<RawSpan> _dedupeExactRanges(List<RawSpan> spans) {
    final seen = <String>{};
    final out = <RawSpan>[];
    for (final s in spans) {
      final key = '${s.start}:${s.end}';
      if (seen.add(key)) out.add(s);
    }
    return out;
  }

  /// Overlap resolution: spans must not overlap in the final output.
  ///
  /// Algorithm — greedy interval scheduling by priority:
  /// 1. Rank every candidate span by (confidence desc, length desc, start
  ///    asc) — deterministic beats likely beats candidate; among equal
  ///    confidence, the longer match wins (it's more specific); ties beyond
  ///    that resolve by document order for determinism.
  /// 2. Walk the ranked list and greedily accept a span only if it doesn't
  ///    overlap any span already accepted. Because higher-priority spans are
  ///    considered first, a deterministic DATE always beats a candidate
  ///    OTHER_ID that happens to cover part of it, etc.
  ///
  /// This is O(n^2) in the number of raw candidate spans, which is fine for
  /// report-length text (a handful of pages, at most a few hundred spans).
  static List<RawSpan> _resolveOverlaps(List<RawSpan> spans) {
    int confidenceRank(SpanConfidence c) => switch (c) {
      SpanConfidence.deterministic => 3,
      SpanConfidence.likely => 2,
      SpanConfidence.candidate => 1,
    };

    final ranked = List<RawSpan>.from(spans)
      ..sort((a, b) {
        final byConfidence =
            confidenceRank(b.confidence).compareTo(confidenceRank(a.confidence));
        if (byConfidence != 0) return byConfidence;
        final byLength = (b.end - b.start).compareTo(a.end - a.start);
        if (byLength != 0) return byLength;
        return a.start.compareTo(b.start);
      });

    final accepted = <RawSpan>[];
    for (final candidate in ranked) {
      final overlaps = accepted.any(
        (a) => candidate.start < a.end && a.start < candidate.end,
      );
      if (!overlaps) accepted.add(candidate);
    }
    return accepted;
  }

  /// Assigns indexed placeholders so the same original value (same
  /// category, case/whitespace-insensitive) always maps to the same
  /// placeholder — coreference survives redaction for downstream LLM
  /// extraction.
  static List<RedactionSpan> _assignPlaceholders(List<RawSpan> resolved) {
    final indexByCategory = <String, Map<String, int>>{};
    final spans = <RedactionSpan>[];

    for (final r in resolved) {
      final normalized = r.originalText.trim().toLowerCase();
      final categoryIndex = indexByCategory.putIfAbsent(r.category, () => {});
      final index =
          categoryIndex.putIfAbsent(normalized, () => categoryIndex.length + 1);

      spans.add(RedactionSpan(
        start: r.start,
        end: r.end,
        category: r.category,
        placeholder: '[${r.category}_$index]',
        confidence: r.confidence,
        source: r.source,
        originalText: r.originalText,
      ));
    }

    return spans;
  }
}
