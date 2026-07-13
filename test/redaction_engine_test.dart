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
  });
}
