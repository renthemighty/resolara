/// On-device first-pass redaction.
/// Rule-based regex replacement of common patient-identifying fields.
/// Server-side residual PII checks are a second-pass safeguard only.
class RedactionService {
  static final _rules = <(RegExp, String)>[
    // Patient / name header lines
    (
      RegExp(
        r'\b(Patient|Name)\s*:?\s*[A-Z][a-zA-Z\u00C0-\u017E\-]+(,?\s+[A-Z][a-zA-Z\u00C0-\u017E\-]+)+',
        caseSensitive: false,
      ),
      '[PATIENT_NAME]',
    ),

    // Date of birth
    (
      RegExp(
        r'\b(D\.?O\.?B\.?|Date\s+of\s+Birth)\s*:?\s*\d{1,2}[/\-\.]\d{1,2}[/\-\.]\d{2,4}',
        caseSensitive: false,
      ),
      '[DOB]',
    ),
    (
      RegExp(
        r'\b(D\.?O\.?B\.?|Date\s+of\s+Birth)\s*:?\s*[A-Za-z]+\.?\s+\d{1,2},?\s+\d{4}',
        caseSensitive: false,
      ),
      '[DOB]',
    ),

    // MRN / record / file / patient ID
    (
      RegExp(
        r'\b(MRN|Medical\s+Record\s+(No\.?|Number)?|Record\s+(No\.?|Number)|File\s+(No\.?|Number)|Patient\s+ID)\s*:?\s*[\w\-]+',
        caseSensitive: false,
      ),
      '[MRN]',
    ),

    // Phone numbers (NA formats)
    (
      RegExp(r'\b(\+?1[\s\-\.]?)?\(?\d{3}\)?[\s\-\.]?\d{3}[\s\-\.]?\d{4}\b'),
      '[PHONE]',
    ),

    // Email addresses
    (
      RegExp(r'\b[\w._%+\-]+@[\w.\-]+\.[a-zA-Z]{2,}\b'),
      '[EMAIL]',
    ),

    // Street addresses (basic)
    (
      RegExp(
        r'\b\d{1,6}\s+[A-Z][a-zA-Z]+(\s+[A-Z][a-zA-Z]+)?\s+(St\.?|Street|Ave\.?|Avenue|Blvd\.?|Boulevard|Rd\.?|Road|Drive|Dr\.?|Lane|Ln\.?|Court|Ct\.?|Way|Place|Pl\.?)\b',
        caseSensitive: false,
      ),
      '[ADDRESS]',
    ),
  ];

  static RedactionResult redact(String rawText) {
    String text = rawText;
    int totalRedacted = 0;
    final Map<String, int> summary = {};

    for (final (pattern, placeholder) in _rules) {
      final matches = pattern.allMatches(text).length;
      if (matches > 0) {
        text = text.replaceAll(pattern, placeholder);
        totalRedacted += matches;
        final key = placeholder.replaceAll(RegExp(r'[\[\]]'), '');
        summary[key] = (summary[key] ?? 0) + matches;
      }
    }

    return RedactionResult(
      redactedText: text,
      totalItemsRedacted: totalRedacted,
      summary: summary,
    );
  }
}

class RedactionResult {
  final String redactedText;
  final int totalItemsRedacted;
  final Map<String, int> summary;

  const RedactionResult({
    required this.redactedText,
    required this.totalItemsRedacted,
    required this.summary,
  });

  bool get hasRedactions => totalItemsRedacted > 0;

  String get summaryString {
    if (!hasRedactions) return 'No identifying information detected.';
    final parts = summary.entries
        .map((e) => '${e.value} ${e.key.toLowerCase()}')
        .toList();
    return '${parts.join(', ')} redacted';
  }
}
