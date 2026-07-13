/// Compile-time submission gate.
///
/// [OcrService.submitJob] requires a [RedactionApproval] instance. The only
/// way to construct one is the private [RedactionApproval._internal]
/// constructor below, and the only code that can reach a private member of
/// this library is code declared *inside this same library* — Dart privacy
/// is per-library, not per-file. [RedactionReviewScreen] is declared in
/// redaction_review_screen.dart, which is included here via `part`, so it
/// shares this library and can call `RedactionApproval._internal(...)`.
/// Every other file in the app (including reader_screen.dart) is a
/// different library and cannot name `_internal` at all — the compiler
/// rejects it as an undefined identifier, not merely a lint warning. There
/// is no factory, no public constructor, and no other way to mint an
/// instance of this class from outside this library.
///
/// The human review performed by [RedactionReviewScreen] IS the
/// de-identification mechanism of record for this app (see
/// redaction_engine.dart's own doc comment) — this file makes bypassing
/// that review a compile error rather than a code-review convention.
library;

import 'package:flutter/material.dart';
import '../../app/theme/app_theme.dart';
import '../../core/services/redaction/redaction_analysis.dart';
import '../../core/services/redaction/redaction_span.dart';

part 'redaction_review_screen.dart';

/// The practitioner-approved, ready-to-submit result of a redaction review.
///
/// This is the only type [OcrService.submitJob] accepts for cleaned report
/// text. See redaction_review_screen.dart for the review UI that produces
/// instances of this class.
class RedactionApproval {
  final String cleanedText;
  final String summary;
  final int spansAccepted;
  final int spansDismissed;
  final int manualAdditions;
  final bool zeroFindingsAttested;
  final DateTime approvedAt;

  RedactionApproval._internal({
    required this.cleanedText,
    required this.summary,
    required this.spansAccepted,
    required this.spansDismissed,
    required this.manualAdditions,
    required this.zeroFindingsAttested,
    required this.approvedAt,
  });
}
