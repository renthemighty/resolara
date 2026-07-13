import 'redaction_span.dart';

/// Internal pre-resolution detection result. Detectors in `detectors.dart`
/// emit these; `RedactionEngine` resolves overlaps and assigns indexed
/// placeholders to produce the public [RedactionSpan] list.
///
/// Not part of the public API — deliberately not re-exported from a barrel
/// file, so nothing outside the engine should reach for it.
class RawSpan {
  final int start;
  final int end;
  final String category;
  final SpanConfidence confidence;
  final SpanSource source;
  final String originalText;

  RawSpan({
    required this.start,
    required this.end,
    required this.category,
    required this.confidence,
    required this.source,
    required this.originalText,
  });
}
