class Finding {
  final String id;
  final String bodyRegion;
  final String text;
  final String laymanTerm;
  final double confidence; // 0.0–1.0
  final bool piiRisk;
  final int? sourceDocumentIndex;

  const Finding({
    required this.id,
    required this.bodyRegion,
    required this.text,
    this.laymanTerm = '',
    required this.confidence,
    required this.piiRisk,
    this.sourceDocumentIndex,
  });

  factory Finding.fromJson(Map<String, dynamic> json) {
    return Finding(
      id: json['id'] as String? ?? '',
      bodyRegion: json['body_region'] as String? ?? '',
      text: json['finding'] as String? ?? '',
      laymanTerm: json['layman_term'] as String? ?? '',
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0.0,
      piiRisk: json['pii_risk'] as bool? ?? false,
      sourceDocumentIndex: json['source_document_index'] as int?,
    );
  }

  Finding copyWith({String? bodyRegion, String? text, int? sourceDocumentIndex}) {
    return Finding(
      id: id,
      bodyRegion: bodyRegion ?? this.bodyRegion,
      text: text ?? this.text,
      laymanTerm: laymanTerm,
      confidence: confidence,
      piiRisk: piiRisk,
      sourceDocumentIndex: sourceDocumentIndex ?? this.sourceDocumentIndex,
    );
  }

  bool get isLowConfidence => confidence < 0.7;
}

class ExtractionResult {
  final List<Finding> findings;
  final List<String> piiDetected;
  final double overallConfidence;
  final int tokensIn;
  final int tokensOut;

  const ExtractionResult({
    required this.findings,
    required this.piiDetected,
    required this.overallConfidence,
    this.tokensIn = 0,
    this.tokensOut = 0,
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

  ExtractionResult withTokens(int tokensIn, int tokensOut) => ExtractionResult(
        findings: findings,
        piiDetected: piiDetected,
        overallConfidence: overallConfidence,
        tokensIn: tokensIn,
        tokensOut: tokensOut,
      );

  bool get hasPiiWarnings => piiDetected.isNotEmpty;
  bool get hasLowConfidence => findings.any((f) => f.isLowConfidence);

  static ExtractionResult merge(List<ExtractionResult> results) {
    final findings = <Finding>[];
    for (int i = 0; i < results.length; i++) {
      for (final f in results[i].findings) {
        findings.add(f.copyWith(sourceDocumentIndex: i));
      }
    }
    double minConf = 1.0;
    for (final r in results) {
      if (r.overallConfidence < minConf) minConf = r.overallConfidence;
    }
    return ExtractionResult(
      findings: findings,
      piiDetected: results.expand((r) => r.piiDetected).toList(),
      overallConfidence: minConf,
      tokensIn: results.fold(0, (sum, r) => sum + r.tokensIn),
      tokensOut: results.fold(0, (sum, r) => sum + r.tokensOut),
    );
  }
}
