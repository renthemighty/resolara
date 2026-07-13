import 'package:flutter_test/flutter_test.dart';
import 'package:resolara/core/services/redaction/redaction.dart';
import 'package:resolara/core/services/redaction/redaction_span.dart';

void main() {
  group('RedactionEngine', () {
    test('flags an unlabelled name on its own line in the header block', () {
      const text = 'Jane Doe\n'
          'Springfield Clinic\n'
          '\n'
          'History: Right wrist pain after a fall on ice.\n';

      final analysis = RedactionEngine.analyze(text);

      final nameSpans = analysis.spans.where((s) => s.category == 'NAME');
      expect(
        nameSpans.any((s) => s.originalText.contains('Jane')),
        isTrue,
        reason: 'Unlabelled patient name in the demographics block should be flagged',
      );
    });

    test('catches dates of service with no DOB/Date label', () {
      const text = 'Imaging performed on March 3, 2024 at the outpatient '
          'facility. Follow-up scheduled 2024-06-15.';

      final analysis = RedactionEngine.analyze(text);
      final dateSpans = analysis.spans.where((s) => s.category == 'DATE').toList();

      expect(dateSpans.length, greaterThanOrEqualTo(2));
    });

    test('catches an OHIP health card number', () {
      const text = 'OHIP 1234567890AB on file.';

      final analysis = RedactionEngine.analyze(text);

      expect(analysis.spans.any((s) => s.category == 'HEALTH_ID'), isTrue);
    });

    test('does not flag "Colles Fracture" or "Achilles Tendon" as names', () {
      const text = 'Findings: Colles Fracture of the right distal radius. '
          'Achilles Tendon intact bilaterally.';

      final analysis = RedactionEngine.analyze(text);

      final nameSpans = analysis.spans.where((s) => s.category == 'NAME');
      expect(
        nameSpans.any((s) => s.originalText.contains('Colles')),
        isFalse,
      );
      expect(
        nameSpans.any((s) => s.originalText.contains('Achilles')),
        isFalse,
      );
    });

    test('permits ages under 90 but flags 90+', () {
      const text = 'Patient is 84 y.o. male. Grandmother is 94 y.o. and frail.';

      final analysis = RedactionEngine.analyze(text);
      final ageSpans = analysis.spans.where((s) => s.category == 'AGE_90_PLUS');

      expect(ageSpans.any((s) => s.originalText.contains('84')), isFalse);
      expect(ageSpans.any((s) => s.originalText.contains('94')), isTrue);
    });

    test('overlap resolution keeps the higher-confidence span (MRN over generic ID)', () {
      const text = 'MRN: 12345678 confirms identity.';

      final analysis = RedactionEngine.analyze(text);

      final overlapping = analysis.spans
          .where((s) => s.originalText.contains('12345678'))
          .toList();

      // Exactly one span should survive over that range.
      expect(overlapping.length, 1);
      expect(overlapping.first.category, 'MRN');
      expect(overlapping.first.confidence, SpanConfidence.deterministic);
    });

    test('no two accepted spans in the final model overlap', () {
      const text = 'MRN: 12345678, seen 2024-06-15, contact john@example.com, '
          '555-123-4567, 94 y.o., M1A 1A1, Colles Fracture noted, Jane Doe present.';

      final analysis = RedactionEngine.analyze(text);
      final sorted = List.of(analysis.spans)
        ..sort((a, b) => a.start.compareTo(b.start));

      for (var i = 1; i < sorted.length; i++) {
        expect(
          sorted[i].start >= sorted[i - 1].end,
          isTrue,
          reason: 'Spans ${sorted[i - 1]} and ${sorted[i]} overlap',
        );
      }
    });

    test('buildRedactedText applies only accepted spans with correct offsets', () {
      const text = 'Contact john@example.com or call 555-123-4567 today.';

      final analysis = RedactionEngine.analyze(text);
      final email = analysis.spans.firstWhere((s) => s.category == 'EMAIL');
      final phone = analysis.spans.firstWhere((s) => s.category == 'PHONE');

      email.decision = SpanDecision.accepted;
      phone.decision = SpanDecision.accepted;

      expect(
        analysis.buildRedactedText(),
        'Contact ${email.placeholder} or call ${phone.placeholder} today.',
      );
    });

    test('the same name value gets the same indexed placeholder every time', () {
      const text = 'Mr. Smith presents today. Later, Mr. Smith returned for '
          'follow-up.';

      final analysis = RedactionEngine.analyze(text);
      final smithSpans = analysis.spans
          .where((s) => s.originalText.toLowerCase() == 'mr. smith')
          .toList();

      expect(smithSpans.length, 2);
      expect(smithSpans[0].placeholder, smithSpans[1].placeholder);
      expect(smithSpans[0].placeholder, '[NAME_1]');
    });

    test('zero findings on identifier-free text yields RiskLevel.high', () {
      const text = 'lorem ipsum dolor sit amet consectetur adipiscing elit '
          'sed do eiusmod tempor incididunt ut labore et dolore magna aliqua';

      final analysis = RedactionEngine.analyze(text);

      expect(analysis.spans, isEmpty);
      expect(analysis.risk, RiskLevel.high);
    });

    test('RiskLevel.high also triggers on a pending candidate-confidence name', () {
      const text = 'Jane Doe\nSome unrelated prose without other identifiers.\n';

      final analysis = RedactionEngine.analyze(text);
      final hasCandidateName = analysis.spans.any(
        (s) => s.category == 'NAME' && s.confidence == SpanConfidence.candidate,
      );

      expect(hasCandidateName, isTrue);
      expect(analysis.risk, RiskLevel.high);
    });

    // -------------------------------------------------------------------
    // Bug 1 — allowlist poisoning: names adjacent to a structural word
    // must survive per-token, not be swallowed by whole-run suppression.
    // -------------------------------------------------------------------

    test('flags a name immediately after "Patient" with no punctuation', () {
      const text = 'Patient John Smith presented today.';
      final analysis = RedactionEngine.analyze(text);
      final names = analysis.spans.where((s) => s.category == 'NAME');
      expect(names.any((s) => s.originalText == 'John Smith'), isTrue);
    });

    test('flags a name immediately after "Male"', () {
      const text = 'Male Robert Klein, 45, knee pain.';
      final analysis = RedactionEngine.analyze(text);
      final names = analysis.spans.where((s) => s.category == 'NAME');
      expect(names.any((s) => s.originalText == 'Robert Klein'), isTrue);
    });

    test('flags a single-word name immediately after "Left"', () {
      const text = 'Left Anderson clavicle fracture';
      final analysis = RedactionEngine.analyze(text);
      final names = analysis.spans.where((s) => s.category == 'NAME');
      expect(names.any((s) => s.originalText == 'Anderson'), isTrue);
    });

    test('flags a name immediately after "Referring" with no "Physician"', () {
      const text = 'Referring Michael Brown ordered MRI';
      final analysis = RedactionEngine.analyze(text);
      final names = analysis.spans.where((s) => s.category == 'NAME');
      expect(names.any((s) => s.originalText == 'Michael Brown'), isTrue);
      // "MRI" itself must never be flagged as a name.
      expect(names.any((s) => s.originalText.contains('MRI')), isFalse);
    });

    test('flags the full multi-word name after "Patient" (Nguyen Thi Hoa)', () {
      const text = 'Patient Nguyen Thi Hoa presented';
      final analysis = RedactionEngine.analyze(text);
      final names = analysis.spans.where((s) => s.category == 'NAME');
      expect(names.any((s) => s.originalText == 'Nguyen Thi Hoa'), isTrue);
      // The old bug only leaked fragments — make sure we're not still
      // fragmenting the name into two separate partial spans instead of
      // catching it whole.
      expect(names.any((s) => s.originalText == 'Thi Hoa'), isFalse);
      expect(names.any((s) => s.originalText == 'Nguyen'), isFalse);
    });

    test('"Left Shoulder" is still never flagged as a name (no regression)', () {
      const text = 'Left Shoulder shows no acute abnormality.';
      final analysis = RedactionEngine.analyze(text);
      final names = analysis.spans.where((s) => s.category == 'NAME');
      expect(names.any((s) => s.originalText.contains('Left')), isFalse);
      expect(names.any((s) => s.originalText.contains('Shoulder')), isFalse);
    });

    test('"Right Knee" is still never flagged as a name (no regression)', () {
      const text = 'Right Knee examined, unremarkable.';
      final analysis = RedactionEngine.analyze(text);
      final names = analysis.spans.where((s) => s.category == 'NAME');
      expect(names.any((s) => s.originalText.contains('Right')), isFalse);
      expect(names.any((s) => s.originalText.contains('Knee')), isFalse);
    });

    // -------------------------------------------------------------------
    // Bug 2 — lowercase names after an explicit name label.
    // -------------------------------------------------------------------

    test('flags a lowercase name after "Patient:"', () {
      const text = 'Patient: john smith';
      final analysis = RedactionEngine.analyze(text);
      final names = analysis.spans.where((s) => s.category == 'NAME');
      expect(names.any((s) => s.originalText == 'john smith'), isTrue);
    });

    test('flags a lowercase apostrophe name after "name:"', () {
      const text = "name: mary o'brien, dob 1975";
      final analysis = RedactionEngine.analyze(text);
      final names = analysis.spans.where((s) => s.category == 'NAME');
      expect(names.any((s) => s.originalText == "mary o'brien"), isTrue);
    });

    // -------------------------------------------------------------------
    // Bug 3 — spaced/hyphenated health-card & MRN numbers must redact as
    // one whole group, not leak a fragment.
    // -------------------------------------------------------------------

    test('redacts a fully spaced Health Card number as one group', () {
      const text = 'Health Card: 1234 567 890 XY';
      final analysis = RedactionEngine.analyze(text);
      final healthSpans =
          analysis.spans.where((s) => s.category == 'HEALTH_ID').toList();
      expect(healthSpans.any((s) => s.originalText.contains('1234 567 890 XY')),
          isTrue);
      // No fragment of the number should be left un-covered by any span.
      final covered = analysis.spans.any(
        (s) => s.start <= text.indexOf('567') && s.end >= text.indexOf('890') + 3,
      );
      expect(covered, isTrue);
    });

    test('redacts a fully spaced OHIP # number as one group', () {
      const text = 'OHIP # 5544 332 211 AB';
      final analysis = RedactionEngine.analyze(text);
      final healthSpans =
          analysis.spans.where((s) => s.category == 'HEALTH_ID').toList();
      expect(
        healthSpans.any((s) => s.originalText.contains('5544 332 211 AB')),
        isTrue,
      );
    });

    test('redacts a fully spaced MRN as one group, not as a NAME', () {
      const text = 'MRN: 44 82 19 7';
      final analysis = RedactionEngine.analyze(text);
      final mrnSpans = analysis.spans.where((s) => s.category == 'MRN').toList();
      expect(mrnSpans.any((s) => s.originalText.contains('44 82 19 7')), isTrue);

      // The digits must not also leak through as an un-redacted NAME span
      // over the same range.
      final nameOverDigits = analysis.spans.where(
        (s) => s.category == 'NAME' && s.originalText.contains(RegExp(r'\d')),
      );
      expect(nameOverDigits, isEmpty);
    });

    // -------------------------------------------------------------------
    // Bug 4 — Ontario OHIP / Québec RAMQ separator-tolerant recall, and
    // the hyphenated 90+ age fix.
    // -------------------------------------------------------------------

    test('flags an unlabelled, separator-tolerant Ontario OHIP number', () {
      const text = 'Card on file: 1234 567 890 XY, confirmed.';
      final analysis = RedactionEngine.analyze(text);
      expect(
        analysis.spans.any(
          (s) => s.category == 'HEALTH_ID' && s.originalText.contains('1234 567 890 XY'),
        ),
        isTrue,
      );
    });

    test('flags an unlabelled Québec RAMQ number', () {
      const text = 'Card number ABCD 1234 5678 noted in chart.';
      final analysis = RedactionEngine.analyze(text);
      expect(
        analysis.spans.any(
          (s) => s.category == 'HEALTH_ID' && s.originalText.contains('ABCD 1234 5678'),
        ),
        isTrue,
      );
    });

    test('flags "92-year-old" (hyphenated 90+ age)', () {
      const text = 'A 92-year-old male presents with hip pain.';
      final analysis = RedactionEngine.analyze(text);
      final ageSpans = analysis.spans.where((s) => s.category == 'AGE_90_PLUS');
      expect(ageSpans.any((s) => s.originalText.contains('92')), isTrue);
    });

    test('flags "94 y.o." (spaced 90+ age) — no regression', () {
      const text = 'The patient is 94 y.o. and frail.';
      final analysis = RedactionEngine.analyze(text);
      final ageSpans = analysis.spans.where((s) => s.category == 'AGE_90_PLUS');
      expect(ageSpans.any((s) => s.originalText.contains('94')), isTrue);
    });

    test('"84 y.o." stays unflagged — no regression', () {
      const text = 'The patient is 84 y.o. and active.';
      final analysis = RedactionEngine.analyze(text);
      final ageSpans = analysis.spans.where((s) => s.category == 'AGE_90_PLUS');
      expect(ageSpans.any((s) => s.originalText.contains('84')), isFalse);
    });

    // -------------------------------------------------------------------
    // Bug 5 — RiskLevel.high must also fire for a long multi-line report
    // even when the engine caught something (so it isn't just "elevated").
    // -------------------------------------------------------------------

    test('a long multi-line report forces RiskLevel.high even with spans caught', () {
      const text = 'Springfield Clinic\n'
          'Radiology Report\n'
          '\n'
          'Exam date: 2024-06-15\n'
          'History: fall on ice, right wrist pain.\n'
          'Findings: no acute fracture identified.\n'
          'Impression: unremarkable study.\n';

      final analysis = RedactionEngine.analyze(text);
      // A date was caught (so the old logic would only say "elevated" or
      // "normal" once resolved) — the length heuristic must still force
      // high risk for a real multi-line report.
      expect(analysis.spans.any((s) => s.category == 'DATE'), isTrue);
      expect(analysis.risk, RiskLevel.high);
    });
  });
}
