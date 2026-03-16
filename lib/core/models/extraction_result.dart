class Finding {
  final String id;
  final String bodyRegion;
  final String text;
  final String laymanTerm;
  final double confidence; // 0.0–1.0
  final bool piiRisk;

  const Finding({
    required this.id,
    required this.bodyRegion,
    required this.text,
    this.laymanTerm = '',
    required this.confidence,
    required this.piiRisk,
  });

  factory Finding.fromJson(Map<String, dynamic> json) {
    return Finding(
      id: json['id'] as String? ?? '',
      bodyRegion: json['body_region'] as String? ?? '',
      text: json['finding'] as String? ?? '',
      laymanTerm: json['layman_term'] as String? ?? '',
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0.0,
      piiRisk: json['pii_risk'] as bool? ?? false,
    );
  }

  Finding copyWith({String? bodyRegion, String? text}) {
    return Finding(
      id: id,
      bodyRegion: bodyRegion ?? this.bodyRegion,
      text: text ?? this.text,
      laymanTerm: laymanTerm,
      confidence: confidence,
      piiRisk: piiRisk,
    );
  }

  bool get isLowConfidence => confidence < 0.7;
}

class ExtractionResult {
  final List<Finding> findings;
  final List<String> piiDetected;
  final double overallConfidence;

  const ExtractionResult({
    required this.findings,
    required this.piiDetected,
    required this.overallConfidence,
  });

  factory ExtractionResult.fromJson(Map<String, dynamic> json) {
    final rawFindings = json['findings'] as List<dynamic>? ?? [];
    final rawPii = json['pii_detected'] as List<dynamic>? ?? [];
    return ExtractionResult(
      findings: rawFindings
          .map((f) => Finding.fromJson(f as Map<String, dynamic>))
          .toList(),
      piiDetected: rawPii.map((e) => e as String).toList(),
      overallConfidence:
          (json['overall_confidence'] as num?)?.toDouble() ?? 0.0,
    );
  }

  bool get hasPiiWarnings => piiDetected.isNotEmpty;
  bool get hasLowConfidence => findings.any((f) => f.isLowConfidence);
}
