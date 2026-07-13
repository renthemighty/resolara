/// All individual detectors. Each returns a flat, unresolved list of
/// [RawSpan]s — overlaps between detectors (and between categories) are
/// expected and are resolved centrally by `RedactionEngine`.
///
/// Keep every regex here (not inline in the engine) so detectors can be
/// tested/tuned independently of the overlap-resolution logic.
library;

import 'clinic_identifiers.dart';
import 'medical_allowlist.dart';
import 'raw_span.dart';
import 'redaction_span.dart';

const _monthNames =
    r'Jan(?:uary)?|Feb(?:ruary)?|Mar(?:ch)?|Apr(?:il)?|May|Jun(?:e)?|'
    r'Jul(?:y)?|Aug(?:ust)?|Sep(?:t|tember)?|Oct(?:ober)?|Nov(?:ember)?|'
    r'Dec(?:ember)?';

List<RawSpan> _spansFor(
  Iterable<RegExpMatch> matches,
  String text,
  String category,
  SpanConfidence confidence,
  SpanSource source,
) {
  return [
    for (final m in matches)
      RawSpan(
        start: m.start,
        end: m.end,
        category: category,
        confidence: confidence,
        source: source,
        originalText: text.substring(m.start, m.end),
      ),
  ];
}

// ---------------------------------------------------------------------------
// Deterministic: dates
// ---------------------------------------------------------------------------

List<RawSpan> detectDates(String text) {
  final spans = <RawSpan>[];

  // Numeric: D/M/Y, D-M-Y, D.M.Y (2-4 digit year)
  spans.addAll(_spansFor(
    RegExp(r'\b\d{1,2}[/\-.]\d{1,2}[/\-.]\d{2,4}\b').allMatches(text),
    text,
    'DATE',
    SpanConfidence.deterministic,
    SpanSource.regex,
  ));

  // ISO: YYYY-MM-DD
  spans.addAll(_spansFor(
    RegExp(r'\b\d{4}-\d{2}-\d{2}\b').allMatches(text),
    text,
    'DATE',
    SpanConfidence.deterministic,
    SpanSource.regex,
  ));

  // Month D, YYYY
  spans.addAll(_spansFor(
    RegExp(
      r'\b(?:' + _monthNames + r')\.?\s+\d{1,2},?\s+\d{4}\b',
      caseSensitive: false,
    ).allMatches(text),
    text,
    'DATE',
    SpanConfidence.deterministic,
    SpanSource.regex,
  ));

  // D Month YYYY
  spans.addAll(_spansFor(
    RegExp(
      r'\b\d{1,2}\s+(?:' + _monthNames + r')\.?,?\s+\d{4}\b',
      caseSensitive: false,
    ).allMatches(text),
    text,
    'DATE',
    SpanConfidence.deterministic,
    SpanSource.regex,
  ));

  return spans;
}

// ---------------------------------------------------------------------------
// Deterministic: phone / email / url / ip
// ---------------------------------------------------------------------------

List<RawSpan> detectPhones(String text) {
  final spans = <RawSpan>[];
  spans.addAll(_spansFor(
    RegExp(r'\b(\+?1[\s\-.]?)?\(?\d{3}\)?[\s\-.]?\d{3}[\s\-.]?\d{4}\b')
        .allMatches(text),
    text,
    'PHONE',
    SpanConfidence.deterministic,
    SpanSource.regex,
  ));
  // International: leading + and country code, grouped digits.
  spans.addAll(_spansFor(
    RegExp(r'\+\d{1,3}[\s\-.]?\(?\d{1,4}\)?(?:[\s\-.]?\d{2,4}){2,4}\b')
        .allMatches(text),
    text,
    'PHONE',
    SpanConfidence.deterministic,
    SpanSource.regex,
  ));
  return spans;
}

List<RawSpan> detectEmails(String text) {
  return _spansFor(
    RegExp(r'\b[\w.+-]+@[\w-]+\.[a-zA-Z]{2,}\b').allMatches(text),
    text,
    'EMAIL',
    SpanConfidence.deterministic,
    SpanSource.regex,
  );
}

List<RawSpan> detectUrls(String text) {
  final spans = <RawSpan>[];
  for (final m
      in RegExp(r'\b(?:https?://|www\.)\S+', caseSensitive: false)
          .allMatches(text)) {
    var end = m.end;
    // Trim trailing punctuation that's almost certainly sentence
    // punctuation, not part of the URL.
    while (end > m.start &&
        const {'.', ',', ')', ']', ';', ':', '!', '?'}
            .contains(text[end - 1])) {
      end--;
    }
    if (end <= m.start) continue;
    spans.add(RawSpan(
      start: m.start,
      end: end,
      category: 'URL',
      confidence: SpanConfidence.deterministic,
      source: SpanSource.regex,
      originalText: text.substring(m.start, end),
    ));
  }
  return spans;
}

List<RawSpan> detectIps(String text) {
  final spans = <RawSpan>[];
  spans.addAll(_spansFor(
    RegExp(
      r'\b(?:(?:25[0-5]|2[0-4]\d|1?\d?\d)\.){3}(?:25[0-5]|2[0-4]\d|1?\d?\d)\b',
    ).allMatches(text),
    text,
    'IP',
    SpanConfidence.deterministic,
    SpanSource.regex,
  ));
  // IPv6 (full and common compressed forms) — deliberately conservative to
  // avoid firing on lab-value ratios like "1:2:3".
  spans.addAll(_spansFor(
    RegExp(
      r'\b(?:[A-Fa-f0-9]{1,4}:){3,7}[A-Fa-f0-9]{1,4}\b|'
      r'\b(?:[A-Fa-f0-9]{1,4}:){1,6}:(?:[A-Fa-f0-9]{1,4})?\b',
    ).allMatches(text),
    text,
    'IP',
    SpanConfidence.deterministic,
    SpanSource.regex,
  ));
  return spans;
}

// ---------------------------------------------------------------------------
// Deterministic: SSN / Canadian SIN (Luhn-validated)
// ---------------------------------------------------------------------------

bool _luhnValid(String nineDigits) {
  var sum = 0;
  for (var i = 0; i < nineDigits.length; i++) {
    var d = int.parse(nineDigits[nineDigits.length - 1 - i]);
    if (i % 2 == 1) {
      d *= 2;
      if (d > 9) d -= 9;
    }
    sum += d;
  }
  return sum % 10 == 0;
}

List<RawSpan> detectSsnSin(String text) {
  final spans = <RawSpan>[];

  // US SSN: ddd-dd-dddd
  spans.addAll(_spansFor(
    RegExp(r'\b\d{3}-\d{2}-\d{4}\b').allMatches(text),
    text,
    'SSN',
    SpanConfidence.deterministic,
    SpanSource.regex,
  ));

  // Canadian SIN: 9 digits, optionally grouped 3-3-3, Luhn-valid.
  for (final m
      in RegExp(r'\b\d{3}[\s-]\d{3}[\s-]\d{3}\b|\b\d{9}\b').allMatches(text)) {
    final digits = text.substring(m.start, m.end).replaceAll(RegExp(r'\D'), '');
    if (digits.length == 9 && _luhnValid(digits)) {
      spans.add(RawSpan(
        start: m.start,
        end: m.end,
        category: 'SSN',
        confidence: SpanConfidence.deterministic,
        source: SpanSource.regex,
        originalText: text.substring(m.start, m.end),
      ));
    }
  }

  return spans;
}

// ---------------------------------------------------------------------------
// Deterministic: postal / zip
// ---------------------------------------------------------------------------

bool _hasAddressContext(String text, int matchStart) {
  final w1Start = (matchStart - 40).clamp(0, text.length);
  final before1 = text.substring(w1Start, matchStart);
  // ", ON " / ", NY" style state/province abbreviation right before it.
  if (RegExp(r',\s*[A-Za-z]{2}\.?\s*$').hasMatch(before1)) return true;

  final w2Start = (matchStart - 60).clamp(0, text.length);
  final before2 = text.substring(w2Start, matchStart).toLowerCase();
  const addressWords = [
    'address', 'street', ' st.', ' st ', 'ave', 'avenue', 'blvd',
    'boulevard', 'road', ' rd', 'drive', ' dr.', 'city', 'state',
    'province', 'zip', 'postal', 'suite', 'unit', 'apt',
  ];
  return addressWords.any((w) => before2.contains(w));
}

List<RawSpan> detectPostal(String text) {
  final spans = <RawSpan>[];

  spans.addAll(_spansFor(
    RegExp(
      r'\b[ABCEGHJ-NPRSTVXY]\d[A-Z][ -]?\d[A-Z]\d\b',
      caseSensitive: false,
    ).allMatches(text),
    text,
    'POSTAL',
    SpanConfidence.deterministic,
    SpanSource.regex,
  ));

  for (final m in RegExp(r'\b\d{5}(?:-\d{4})?\b').allMatches(text)) {
    if (_hasAddressContext(text, m.start)) {
      spans.add(RawSpan(
        start: m.start,
        end: m.end,
        category: 'POSTAL',
        confidence: SpanConfidence.deterministic,
        source: SpanSource.regex,
        originalText: text.substring(m.start, m.end),
      ));
    }
  }

  return spans;
}

// ---------------------------------------------------------------------------
// Deterministic: age 90+
// ---------------------------------------------------------------------------

List<RawSpan> detectAge90Plus(String text) {
  return _spansFor(
    RegExp(
      r'\b(9\d|1[0-4]\d)\s*(y\.?o\.?|yo|yrs?|years?[\s-]old)\b',
      caseSensitive: false,
    ).allMatches(text),
    text,
    'AGE_90_PLUS',
    SpanConfidence.deterministic,
    SpanSource.regex,
  );
}

// ---------------------------------------------------------------------------
// Deterministic: labelled IDs (MRN / ACCOUNT / LICENCE / DEVICE_ID / HEALTH_ID)
// ---------------------------------------------------------------------------

List<RawSpan> _labelledId(String text, String labelAlternation, String category) {
  final re = RegExp(
    r'\b(?:' + labelAlternation + r')\s*[:#]?\s*([A-Za-z0-9][A-Za-z0-9\-]{2,20})',
    caseSensitive: false,
  );
  return _spansFor(
    re.allMatches(text),
    text,
    category,
    SpanConfidence.deterministic,
    SpanSource.regex,
  );
}

List<RawSpan> detectLabelledIds(String text) {
  final spans = <RawSpan>[];

  spans.addAll(_labelledId(
    text,
    r'MRN|Medical\s+Record\s*(?:No\.?|Number)?|Chart\s*#|Accession(?:\s*(?:No\.?|Number|#))?',
    'MRN',
  ));

  spans.addAll(_labelledId(
    text,
    r'Acct(?:\s*(?:No\.?|Number|#))?|Account(?:\s*(?:No\.?|Number|#))?|'
    r'Invoice(?:\s*(?:No\.?|Number|#))?|Claim(?:\s*(?:No\.?|Number|#))?',
    'ACCOUNT',
  ));

  spans.addAll(_labelledId(
    text,
    r'Licen[cs]e(?:\s*(?:No\.?|Number|#))?|Cert(?:ificate)?(?:\s*(?:No\.?|Number|#))?',
    'LICENCE',
  ));

  spans.addAll(_labelledId(
    text,
    r'Serial(?:\s*(?:No\.?|Number|#))?|S\/N|Device\s*ID|UDI',
    'DEVICE_ID',
  ));

  return spans;
}

List<RawSpan> detectHealthId(String text) {
  final spans = <RawSpan>[];

  spans.addAll(_labelledId(
    text,
    r'Health\s*Card|HC|PHN|OHIP|Policy(?:\s*(?:No\.?|Number|#))?|'
    r'Member\s*(?:No\.?|ID)|Group\s*(?:No\.?|#)',
    'HEALTH_ID',
  ));

  // Ontario OHIP: 10 digits + 2-letter version code, unlabelled.
  spans.addAll(_spansFor(
    RegExp(r'\b\d{10}[A-Za-z]{2}\b').allMatches(text),
    text,
    'HEALTH_ID',
    SpanConfidence.deterministic,
    SpanSource.regex,
  ));

  // BC PHN: 10 digits starting with 9, unlabelled.
  spans.addAll(_spansFor(
    RegExp(r'\b9\d{9}\b').allMatches(text),
    text,
    'HEALTH_ID',
    SpanConfidence.deterministic,
    SpanSource.regex,
  ));

  // Alberta ULI: bare 9 digits, unlabelled. Broad by nature (see engine
  // report notes) — overlap resolution + SIN Luhn-check ordering keeps
  // this from clobbering validated SINs.
  spans.addAll(_spansFor(
    RegExp(r'\b\d{9}\b').allMatches(text),
    text,
    'HEALTH_ID',
    SpanConfidence.deterministic,
    SpanSource.regex,
  ));

  return spans;
}

// ---------------------------------------------------------------------------
// Deterministic: address
// ---------------------------------------------------------------------------

List<RawSpan> detectAddress(String text) {
  final spans = <RawSpan>[];

  spans.addAll(_spansFor(
    RegExp(
      r'\b\d{1,6}\s+[A-Z][a-zA-Z]+(?:\s+[A-Z][a-zA-Z]+)?\s+'
      r'(?:St\.?|Street|Ave\.?|Avenue|Blvd\.?|Boulevard|Rd\.?|Road|Drive|Dr\.?|'
      r'Lane|Ln\.?|Court|Ct\.?|Way|Place|Pl\.?|Terrace|Cres(?:cent)?\.?)\b'
      r'(?:\s*,?\s*(?:Unit|Apt\.?|Suite|Ste\.?|#)\s*[\w-]+)?',
      caseSensitive: false,
    ).allMatches(text),
    text,
    'ADDRESS',
    SpanConfidence.deterministic,
    SpanSource.regex,
  ));

  spans.addAll(_spansFor(
    RegExp(
      r'\b(?:P\.?\s*O\.?\s*Box|Post\s+Office\s+Box)\s*#?\s*\d+\b',
      caseSensitive: false,
    ).allMatches(text),
    text,
    'ADDRESS',
    SpanConfidence.deterministic,
    SpanSource.regex,
  ));

  spans.addAll(_spansFor(
    RegExp(
      r'\b(?:R\.?R\.?|Rural\s+Route)\s*#?\s*\d+\b',
      caseSensitive: false,
    ).allMatches(text),
    text,
    'ADDRESS',
    SpanConfidence.deterministic,
    SpanSource.regex,
  ));

  return spans;
}

// ---------------------------------------------------------------------------
// Deterministic: clinic's own identifiers (letterhead)
// ---------------------------------------------------------------------------

List<RawSpan> detectClinicIdentifiers(String text, ClinicIdentifiers clinic) {
  final spans = <RawSpan>[];

  void addLiterals(List<String> values, String category) {
    for (final value in values) {
      final v = value.trim();
      if (v.isEmpty) continue;
      final re = RegExp(RegExp.escape(v), caseSensitive: false);
      spans.addAll(_spansFor(
        re.allMatches(text),
        text,
        category,
        SpanConfidence.deterministic,
        SpanSource.clinicList,
      ));
    }
  }

  addLiterals(clinic.names, 'PROVIDER');
  addLiterals(clinic.clinicNames, 'FACILITY');
  addLiterals(clinic.addresses, 'ADDRESS');
  addLiterals(clinic.phones, 'PHONE');

  return spans;
}

// ---------------------------------------------------------------------------
// Likely: provider mentions / titled names
// ---------------------------------------------------------------------------

const _capWord = r"[A-Z][a-zA-ZÀ-ž'\-]+";
// No `^` anchor: matchAsPrefix already anchors the match at the given
// start index, and `^` would instead anchor to true string position 0
// (matchAsPrefix does not treat the start offset as a line/string start).
final _capWordRe = RegExp(_capWord);
final _leadingWhitespaceRe = RegExp(r'\s+');

/// Matches a case-insensitive label (e.g. "Dr.", "Reported by"), then
/// anchors one or two case-*sensitive* capitalized words right after it as
/// the actual name.
///
/// Deliberately split like this: if the whole pattern were case-insensitive
/// (as it used to be), `[A-Z]` inside [_capWord] happily matches lowercase
/// letters too, so "Dr. Smith presents" would swallow "presents" into the
/// match. That both over-captures the span and breaks placeholder
/// coreference — the same name would map to different placeholders
/// depending on whatever lowercase word happened to follow it. Keeping the
/// label case-insensitive but the name capture case-sensitive preserves the
/// intent of [_capWord] (a real capitalized word) while still tolerating
/// label casing variance.
List<RawSpan> _titledName(
  String text,
  String labelAlternation,
  String category, {
  String? optionalPrefix,
}) {
  final labelRe = RegExp(
    r'\b(?:' + labelAlternation + r')\.?\s*:?\s*',
    caseSensitive: false,
  );
  final optionalPrefixRe =
      optionalPrefix == null ? null : RegExp(optionalPrefix, caseSensitive: false);

  final spans = <RawSpan>[];
  for (final labelMatch in labelRe.allMatches(text)) {
    var pos = labelMatch.end;

    if (optionalPrefixRe != null) {
      final prefixMatch = optionalPrefixRe.matchAsPrefix(text, pos);
      if (prefixMatch != null) pos = prefixMatch.end;
    }

    final firstWord = _capWordRe.matchAsPrefix(text, pos);
    if (firstWord == null) continue;
    var end = firstWord.end;

    final gap = _leadingWhitespaceRe.matchAsPrefix(text, end);
    if (gap != null) {
      final secondWord = _capWordRe.matchAsPrefix(text, gap.end);
      if (secondWord != null) end = secondWord.end;
    }

    spans.add(RawSpan(
      start: labelMatch.start,
      end: end,
      category: category,
      confidence: SpanConfidence.likely,
      source: SpanSource.regex,
      originalText: text.substring(labelMatch.start, end),
    ));
  }
  return spans;
}

List<RawSpan> detectProvider(String text) {
  return _titledName(
    text,
    r'Reported\s+by|Referring\s+Physician|Attending\s+Physician|'
    r'Ordering\s+Physician|Interpreting\s+Physician|Interpreted\s+by|'
    r'Radiologist|Signed\s+by|Dictated\s+by',
    'PROVIDER',
    optionalPrefix: r'Dr\.?\s+',
  );
}

List<RawSpan> detectNameTitle(String text) {
  return _titledName(
    text,
    r'Mr|Mrs|Ms|Miss|Dr|Doctor',
    'NAME',
  );
}

// ---------------------------------------------------------------------------
// Candidate: header-zone names, capitalized bigrams, generic ID
// ---------------------------------------------------------------------------

bool _wordAllowlisted(String word) => medicalWords.contains(word.toLowerCase());

bool _phraseAllowlisted(String phrase) =>
    medicalPhrases.contains(phrase.toLowerCase());

bool _isLikelyClinicalRun(String matchText) {
  if (_phraseAllowlisted(matchText)) return true;
  // A real person's name essentially never shares a word with core
  // anatomy/modality/report-structure vocabulary, so any hit is enough to
  // suppress the run.
  final words = matchText.split(RegExp(r'\s+'));
  return words.any(_wordAllowlisted);
}

List<RawSpan> detectNameHeaderZone(String text) {
  final spans = <RawSpan>[];
  final runRe = RegExp('\\b$_capWord(?:\\s+$_capWord){0,3}\\b');

  var pos = 0;
  var lineCount = 0;
  while (pos <= text.length && lineCount < 8) {
    final nl = text.indexOf('\n', pos);
    final lineEnd = nl == -1 ? text.length : nl;
    final line = text.substring(pos, lineEnd);

    for (final m in runRe.allMatches(line)) {
      final matched = line.substring(m.start, m.end);
      if (_isLikelyClinicalRun(matched)) continue;
      spans.add(RawSpan(
        start: pos + m.start,
        end: pos + m.end,
        category: 'NAME',
        confidence: SpanConfidence.candidate,
        source: SpanSource.headerZone,
        originalText: matched,
      ));
    }

    lineCount++;
    if (nl == -1) break;
    pos = nl + 1;
  }

  return spans;
}

List<RawSpan> detectNameBigram(String text) {
  final spans = <RawSpan>[];
  final re = RegExp('\\b$_capWord\\s+$_capWord\\b');
  for (final m in re.allMatches(text)) {
    final matched = text.substring(m.start, m.end);
    if (_isLikelyClinicalRun(matched)) continue;
    spans.add(RawSpan(
      start: m.start,
      end: m.end,
      category: 'NAME',
      confidence: SpanConfidence.candidate,
      source: SpanSource.bigram,
      originalText: matched,
    ));
  }
  return spans;
}

double _digitRatio(String token) {
  final digits = token.replaceAll(RegExp(r'[^0-9]'), '').length;
  return digits / token.length;
}

List<RawSpan> detectOtherId(String text) {
  final spans = <RawSpan>[];
  for (final m in RegExp(r'\b[A-Za-z0-9][A-Za-z0-9\-]{5,}\b').allMatches(text)) {
    final token = text.substring(m.start, m.end);
    if (_digitRatio(token) < 0.6) continue;
    spans.add(RawSpan(
      start: m.start,
      end: m.end,
      category: 'OTHER_ID',
      confidence: SpanConfidence.candidate,
      source: SpanSource.regex,
      originalText: token,
    ));
  }
  return spans;
}
