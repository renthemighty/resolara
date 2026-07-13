part of 'redaction_approval.dart';

/// Practitioner review gate for on-device redaction.
///
/// This screen is the de-identification mechanism of record: the engine
/// (`RedactionEngine.analyze`) only proposes candidate spans, high recall by
/// design. Nothing is sent to the server until a human has resolved every
/// span and, in the zero-findings case, explicitly attested to having read
/// the full text. The raw report text ([RedactionAnalysis.originalText])
/// lives only in this screen's memory for the lifetime of the review — it is
/// never persisted, logged, or printed here or in the caller.
class RedactionReviewScreen extends StatefulWidget {
  final RedactionAnalysis analysis;

  const RedactionReviewScreen({super.key, required this.analysis});

  @override
  State<RedactionReviewScreen> createState() => _RedactionReviewScreenState();
}

class _RedactionReviewScreenState extends State<RedactionReviewScreen> {
  final _scrollController = ScrollController();
  bool _hasScrolledToEnd = false;
  bool _attested = false;
  int _manualCounter = 0;

  @override
  void initState() {
    super.initState();
    // Deterministic spans are shown already-redacted by default — the
    // practitioner only has to actively resolve the lower-confidence
    // likely/candidate spans. Tapping a deterministic chip can still
    // restore it.
    for (final s in widget.analysis.spans) {
      if (s.confidence == SpanConfidence.deterministic &&
          s.decision == SpanDecision.pending) {
        s.decision = SpanDecision.accepted;
      }
    }
    _scrollController.addListener(_onScrollChanged);
    // Covers the case where the text fits on screen without scrolling —
    // maxScrollExtent is 0 once the first frame is laid out, so the scroll
    // gate is satisfied immediately instead of being permanently stuck.
    WidgetsBinding.instance.addPostFrameCallback((_) => _onScrollChanged());
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScrollChanged);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScrollChanged() {
    if (_hasScrolledToEnd || !_scrollController.hasClients) return;
    final position = _scrollController.position;
    if (position.maxScrollExtent <= 0 ||
        position.pixels >= position.maxScrollExtent - 4) {
      setState(() => _hasScrolledToEnd = true);
    }
  }

  bool get _isZeroFindings => widget.analysis.spans.isEmpty;

  /// All submit preconditions in one place, recomputed on every relevant
  /// state change. See class doc — nothing ships to the server unless every
  /// one of these holds.
  bool get _canSubmit {
    final noPending = widget.analysis.spans
        .every((s) => s.decision != SpanDecision.pending);
    if (!noPending) return false;
    if (!_hasScrolledToEnd) return false;
    if (_isZeroFindings && !_attested) return false;
    // buildRedactedText() returns originalText unchanged when there are no
    // accepted spans, so this single check also covers the zero-findings
    // unredacted-send case — no separate branch needed.
    if (widget.analysis.buildRedactedText().trim().isEmpty) return false;
    return true;
  }

  Future<void> _openDeterministicSheet(RedactionSpan span) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _DeterministicDecisionSheet(span: span),
    );
    if (action == null || !mounted) return;
    setState(() {
      span.decision =
          action == 'keep' ? SpanDecision.accepted : SpanDecision.dismissed;
    });
  }

  Future<void> _openReviewSheet(RedactionSpan span) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _CandidateDecisionSheet(span: span),
    );
    if (action == null || !mounted) return;
    setState(() {
      span.decision =
          action == 'redact' ? SpanDecision.accepted : SpanDecision.dismissed;
    });
  }

  void _handleSpanTap(RedactionSpan span) {
    if (span.confidence == SpanConfidence.deterministic) {
      _openDeterministicSheet(span);
    } else {
      _openReviewSheet(span);
    }
  }

  Future<void> _openManualRedact() async {
    final result = await Navigator.of(context).push<_ManualRedactResult>(
      MaterialPageRoute(
        builder: (_) => _ManualRedactScreen(
          originalText: widget.analysis.originalText,
          existingSpans: widget.analysis.spans,
        ),
      ),
    );
    if (result == null || !mounted) return;

    final selectedText =
        widget.analysis.originalText.substring(result.start, result.end);
    _manualCounter += 1;
    final span = RedactionSpan(
      start: result.start,
      end: result.end,
      category: result.category,
      // Manual placeholder indexing is independent of the engine's own
      // per-category counters — avoids needing to inspect/replicate that
      // scheme just to add one more span.
      placeholder: '[${result.category}_MANUAL_$_manualCounter]',
      confidence: SpanConfidence.deterministic,
      source: SpanSource.manual,
      originalText: selectedText,
      decision: SpanDecision.accepted,
    );
    setState(() {
      widget.analysis.spans.add(span);
      widget.analysis.spans.sort((a, b) => a.start.compareTo(b.start));
    });
  }

  void _submit() {
    if (!_canSubmit) return;
    final spans = widget.analysis.spans;
    final approval = RedactionApproval._internal(
      cleanedText: widget.analysis.buildRedactedText(),
      summary: widget.analysis.buildSummary(),
      spansAccepted:
          spans.where((s) => s.decision == SpanDecision.accepted).length,
      spansDismissed:
          spans.where((s) => s.decision == SpanDecision.dismissed).length,
      manualAdditions:
          spans.where((s) => s.source == SpanSource.manual).length,
      zeroFindingsAttested: _isZeroFindings && _attested,
      approvedAt: DateTime.now(),
    );
    Navigator.of(context).pop(approval);
  }

  void _cancel() => Navigator.of(context).pop();

  List<InlineSpan> _buildInlineSpans(TextStyle bodyStyle) {
    final text = widget.analysis.originalText;
    final spans = List<RedactionSpan>.from(widget.analysis.spans)
      ..sort((a, b) => a.start.compareTo(b.start));

    final result = <InlineSpan>[];
    var cursor = 0;
    for (final s in spans) {
      if (s.start < cursor) continue; // defensive: engine guarantees no overlap
      if (s.start > cursor) {
        result.add(TextSpan(text: text.substring(cursor, s.start), style: bodyStyle));
      }
      result.add(WidgetSpan(
        alignment: PlaceholderAlignment.middle,
        child: _SpanChip(span: s, onTap: () => _handleSpanTap(s)),
      ));
      cursor = s.end;
    }
    if (cursor < text.length) {
      result.add(TextSpan(text: text.substring(cursor), style: bodyStyle));
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bodyStyle = TextStyle(
      fontSize: 14,
      height: 1.6,
      color: isDark ? AppTheme.warmStone : AppTheme.emerald,
    );

    final acceptedCount = widget.analysis.spans
        .where((s) => s.decision == SpanDecision.accepted)
        .length;
    final pendingCount = widget.analysis.spans
        .where((s) => s.decision == SpanDecision.pending)
        .length;

    return Scaffold(
      appBar: AppBar(title: const Text('Privacy Review')),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                controller: _scrollController,
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _SummaryHeader(acceptedCount: acceptedCount, pendingCount: pendingCount),
                    const SizedBox(height: 16),
                    if (_isZeroFindings) ...[
                      const _ZeroFindingsBanner(),
                      const SizedBox(height: 12),
                      _AttestationCheckbox(
                        value: _attested,
                        onChanged: (v) => setState(() => _attested = v),
                      ),
                      const SizedBox(height: 16),
                    ],
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Text.rich(
                          TextSpan(children: _buildInlineSpans(bodyStyle)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    OutlinedButton.icon(
                      onPressed: _openManualRedact,
                      icon: const Icon(Icons.format_paint_outlined, size: 18),
                      label: const Text('Redact more…'),
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ),
            _ReviewBottomBar(
              canSubmit: _canSubmit,
              isZeroFindings: _isZeroFindings,
              onCancel: _cancel,
              onSubmit: _submit,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Summary header ───────────────────────────────────────────────────────────

class _SummaryHeader extends StatelessWidget {
  final int acceptedCount;
  final int pendingCount;
  const _SummaryHeader({required this.acceptedCount, required this.pendingCount});

  @override
  Widget build(BuildContext context) {
    final label = pendingCount > 0
        ? '$acceptedCount redacted · $pendingCount need${pendingCount == 1 ? 's' : ''} your review'
        : '$acceptedCount redacted';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: pendingCount > 0
                ? AppTheme.gold.withAlpha(40)
                : AppTheme.emerald.withAlpha(30),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: pendingCount > 0 ? AppTheme.gold : AppTheme.emerald,
            ),
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Nothing has been sent yet. Confirm what leaves this device.',
          style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
        ),
      ],
    );
  }
}

// ── Zero-findings banner + attestation ───────────────────────────────────────

class _ZeroFindingsBanner extends StatelessWidget {
  const _ZeroFindingsBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.error.withAlpha(30),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.error, width: 1),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.warning_amber_rounded, color: AppTheme.error, size: 20),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'No identifying information was detected. This is unusual for a '
              'medical report — read the text carefully.',
              style: TextStyle(
                fontSize: 13,
                color: AppTheme.error,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AttestationCheckbox extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;
  const _AttestationCheckbox({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => onChanged(!value),
      borderRadius: BorderRadius.circular(12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Checkbox(
            value: value,
            onChanged: (v) => onChanged(v ?? false),
            activeColor: AppTheme.emerald,
          ),
          const Expanded(
            child: Padding(
              padding: EdgeInsets.only(top: 12),
              child: Text(
                'I have reviewed the full text and confirm it contains no '
                'patient-identifying information.',
                style: TextStyle(fontSize: 13),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Bottom action bar ─────────────────────────────────────────────────────────

class _ReviewBottomBar extends StatelessWidget {
  final bool canSubmit;
  final bool isZeroFindings;
  final VoidCallback onCancel;
  final VoidCallback onSubmit;

  const _ReviewBottomBar({
    required this.canSubmit,
    required this.isZeroFindings,
    required this.onCancel,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: const Border(top: BorderSide(color: AppTheme.sage, width: 0.5)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ElevatedButton(
            onPressed: canSubmit ? onSubmit : null,
            child: Text(isZeroFindings ? 'Send Unredacted Text' : 'Confirm & Send'),
          ),
          const SizedBox(height: 10),
          OutlinedButton(
            onPressed: onCancel,
            child: const Text('Cancel & Retake'),
          ),
        ],
      ),
    );
  }
}

// ── Span chip ─────────────────────────────────────────────────────────────────

class _SpanChip extends StatelessWidget {
  final RedactionSpan span;
  final VoidCallback onTap;
  const _SpanChip({required this.span, required this.onTap});

  @override
  Widget build(BuildContext context) {
    late final String label;
    late final Color bgColor;
    late final Color borderColor;
    late final Color textColor;
    late final bool underline;

    switch (span.decision) {
      case SpanDecision.pending:
        label = span.originalText;
        bgColor = Colors.transparent;
        borderColor = AppTheme.gold;
        textColor = AppTheme.gold;
        underline = true;
        break;
      case SpanDecision.accepted:
        label = span.placeholder;
        bgColor = AppTheme.emerald;
        borderColor = AppTheme.emerald;
        textColor = AppTheme.warmStone;
        underline = false;
        break;
      case SpanDecision.dismissed:
        label = span.originalText;
        bgColor = Colors.transparent;
        borderColor = AppTheme.sage;
        textColor = AppTheme.sage;
        underline = false;
        break;
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 1),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: bgColor,
          border: Border.all(color: borderColor, width: 1.2),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: textColor,
            decoration: underline ? TextDecoration.underline : null,
            decorationStyle: underline ? TextDecorationStyle.dashed : null,
            decorationColor: AppTheme.gold,
          ),
        ),
      ),
    );
  }
}

// ── Decision sheets ───────────────────────────────────────────────────────────

class _DeterministicDecisionSheet extends StatelessWidget {
  final RedactionSpan span;
  const _DeterministicDecisionSheet({required this.span});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            span.category,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppTheme.textSecondary,
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(height: 6),
          Text('"${span.originalText}"',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop('keep'),
            child: const Text('Keep redacted'),
          ),
          const SizedBox(height: 10),
          OutlinedButton(
            onPressed: () => Navigator.of(context).pop('restore'),
            child: const Text('Restore text'),
          ),
        ],
      ),
    );
  }
}

class _CandidateDecisionSheet extends StatelessWidget {
  final RedactionSpan span;
  const _CandidateDecisionSheet({required this.span});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            span.category,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppTheme.textSecondary,
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(height: 6),
          Text('"${span.originalText}"',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop('redact'),
            child: Text('Redact as ${span.category}'),
          ),
          const SizedBox(height: 10),
          OutlinedButton(
            onPressed: () => Navigator.of(context).pop('dismiss'),
            child: const Text('Not an identifier'),
          ),
        ],
      ),
    );
  }
}

// ── Manual redaction fallback ────────────────────────────────────────────────
//
// Inline rich-text selection (SelectableRegion/onSelectionChanged) cannot be
// statically verified here without a Flutter runtime, so this uses the
// documented-safe fallback: a plain read-only TextField (selection stays
// available via enableInteractiveSelection) with a category picker that
// reads the field's TextEditingController.selection.

class _ManualRedactResult {
  final int start;
  final int end;
  final String category;
  const _ManualRedactResult({
    required this.start,
    required this.end,
    required this.category,
  });
}

class _ManualRedactScreen extends StatefulWidget {
  final String originalText;
  final List<RedactionSpan> existingSpans;
  const _ManualRedactScreen({
    required this.originalText,
    required this.existingSpans,
  });

  @override
  State<_ManualRedactScreen> createState() => _ManualRedactScreenState();
}

class _ManualRedactScreenState extends State<_ManualRedactScreen> {
  late final TextEditingController _controller;
  String? _error;

  static const _categories = <String, String>{
    'NAME': 'Name',
    'DATE': 'Date',
    'MRN': 'MRN',
    'PHONE': 'Phone',
    'EMAIL': 'Email',
    'ADDRESS': 'Address',
    'OTHER_ID': 'Other',
  };

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.originalText);
    _controller.addListener(_onSelectionChanged);
  }

  @override
  void dispose() {
    _controller.removeListener(_onSelectionChanged);
    _controller.dispose();
    super.dispose();
  }

  void _onSelectionChanged() {
    if (mounted) setState(() {});
  }

  bool get _hasSelection =>
      _controller.selection.isValid && !_controller.selection.isCollapsed;

  void _pickCategory(String category) {
    final selection = _controller.selection;
    if (!selection.isValid || selection.isCollapsed) return;
    final start = selection.start;
    final end = selection.end;
    final overlaps =
        widget.existingSpans.any((s) => start < s.end && s.start < end);
    if (overlaps) {
      setState(() => _error = 'Selection overlaps an existing redaction.');
      return;
    }
    Navigator.of(context)
        .pop(_ManualRedactResult(start: start, end: end, category: category));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Redact More Text')),
      body: SafeArea(
        child: Column(
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Select the text you want to redact, then choose a category below.',
                style: TextStyle(color: AppTheme.textSecondary),
              ),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(_error!,
                    style: const TextStyle(color: AppTheme.error, fontSize: 12)),
              ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: SingleChildScrollView(
                  child: TextField(
                    controller: _controller,
                    readOnly: true,
                    maxLines: null,
                    enableInteractiveSelection: true,
                    decoration: const InputDecoration(border: InputBorder.none),
                    style: const TextStyle(fontSize: 14, height: 1.5),
                  ),
                ),
              ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _categories.entries.map((e) {
                    return ElevatedButton(
                      onPressed: _hasSelection ? () => _pickCategory(e.key) : null,
                      style: ElevatedButton.styleFrom(minimumSize: const Size(0, 44)),
                      child: Text(e.value),
                    );
                  }).toList(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
