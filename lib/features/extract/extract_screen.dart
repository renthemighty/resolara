import 'package:flutter/material.dart';
import '../../app/theme/app_theme.dart';
import '../../core/models/extraction_result.dart';
import '../generate/generate_screen.dart';

class ExtractScreen extends StatefulWidget {
  final ExtractionResult extraction;

  const ExtractScreen({super.key, required this.extraction});

  @override
  State<ExtractScreen> createState() => _ExtractScreenState();
}

class _ExtractScreenState extends State<ExtractScreen> {
  late List<Finding> _findings;

  @override
  void initState() {
    super.initState();
    _findings = List.of(widget.extraction.findings);
  }

  void _removeFinding(String id) {
    setState(() => _findings.removeWhere((f) => f.id == id));
  }

  void _editFinding(Finding finding) async {
    final updated = await showModalBottomSheet<Finding>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _EditFindingSheet(finding: finding),
    );
    if (updated != null) {
      setState(() {
        final i = _findings.indexWhere((f) => f.id == updated.id);
        if (i != -1) _findings[i] = updated;
      });
    }
  }

  void _confirm() {
    if (_findings.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('No findings to visualize. Add or restore findings.')),
      );
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => GenerateScreen(findings: List.unmodifiable(_findings)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasLowConf = _findings.any((f) => f.isLowConfidence);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Review Findings'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Column(
        children: [
          if (hasLowConf) const _LowConfidenceBanner(),
          Expanded(
            child: _findings.isEmpty
                ? const _EmptyFindings()
                : ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: _findings.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 8),
                    itemBuilder: (_, i) => _FindingCard(
                      finding: _findings[i],
                      onEdit: () => _editFinding(_findings[i]),
                      onRemove: () => _removeFinding(_findings[i].id),
                    ),
                  ),
          ),
          _ConfirmBar(
            findingCount: _findings.length,
            onConfirm: _confirm,
          ),
        ],
      ),
    );
  }
}

// ── Banners ──────────────────────────────────────────────────────────────────

class _LowConfidenceBanner extends StatelessWidget {
  const _LowConfidenceBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: AppTheme.gold.withAlpha(30),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: const Row(
        children: [
          Icon(Icons.info_outline, color: AppTheme.gold, size: 18),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Some findings have low confidence. Review them before confirming.',
              style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Finding card ─────────────────────────────────────────────────────────────

class _FindingCard extends StatelessWidget {
  final Finding finding;
  final VoidCallback onEdit;
  final VoidCallback onRemove;

  const _FindingCard({
    required this.finding,
    required this.onEdit,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final isLow = finding.isLowConfidence;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    finding.bodyRegion.toUpperCase(),
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Theme.of(context).colorScheme.onSurface.withAlpha(180),
                        letterSpacing: 0.8),
                  ),
                ),
                _ConfidencePill(confidence: finding.confidence),
              ],
            ),
            const SizedBox(height: 8),
            Text(finding.text,
                style: TextStyle(
                    fontSize: 15,
                    color: Theme.of(context).colorScheme.onSurface)),
            if (isLow) ...[
              const SizedBox(height: 8),
              const Row(
                children: [
                  Icon(Icons.info_outline, size: 14, color: AppTheme.gold),
                  SizedBox(width: 4),
                  Text('Low confidence — please verify',
                      style:
                          TextStyle(fontSize: 12, color: AppTheme.gold)),
                ],
              ),
            ],
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_outlined, size: 16),
                  label: const Text('Edit'),
                  style: TextButton.styleFrom(
                      foregroundColor: AppTheme.primary,
                      visualDensity: VisualDensity.compact),
                ),
                const SizedBox(width: 4),
                TextButton.icon(
                  onPressed: onRemove,
                  icon: const Icon(Icons.delete_outline, size: 16),
                  label: const Text('Remove'),
                  style: TextButton.styleFrom(
                      foregroundColor: AppTheme.error,
                      visualDensity: VisualDensity.compact),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ConfidencePill extends StatelessWidget {
  final double confidence;
  const _ConfidencePill({required this.confidence});

  @override
  Widget build(BuildContext context) {
    final pct = (confidence * 100).round();
    final color = confidence >= 0.85
        ? AppTheme.emerald
        : confidence >= 0.7
            ? AppTheme.gold
            : AppTheme.error;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withAlpha(30),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        '$pct%',
        style: TextStyle(
            fontSize: 12, fontWeight: FontWeight.w600, color: color),
      ),
    );
  }
}

// ── Empty state ───────────────────────────────────────────────────────────────

class _EmptyFindings extends StatelessWidget {
  const _EmptyFindings();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search_off, size: 48, color: AppTheme.textSecondary),
            SizedBox(height: 16),
            Text(
              'All findings removed.\nRestore or retake the report if needed.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppTheme.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Confirm bar ───────────────────────────────────────────────────────────────

class _ConfirmBar extends StatelessWidget {
  final int findingCount;
  final VoidCallback onConfirm;

  const _ConfirmBar({required this.findingCount, required this.onConfirm});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppTheme.surface,
        border: Border(top: BorderSide(color: AppTheme.sage, width: 0.5)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '$findingCount finding${findingCount == 1 ? '' : 's'} selected for visualization',
            textAlign: TextAlign.center,
            style: const TextStyle(
                fontSize: 13, color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 10),
          ElevatedButton(
            onPressed: findingCount > 0 ? onConfirm : null,
            child: const Text('Confirm & Generate Visualization'),
          ),
        ],
      ),
    );
  }
}

// ── Edit sheet ────────────────────────────────────────────────────────────────

class _EditFindingSheet extends StatefulWidget {
  final Finding finding;
  const _EditFindingSheet({required this.finding});

  @override
  State<_EditFindingSheet> createState() => _EditFindingSheetState();
}

class _EditFindingSheetState extends State<_EditFindingSheet> {
  late final TextEditingController _regionController;
  late final TextEditingController _textController;

  @override
  void initState() {
    super.initState();
    _regionController =
        TextEditingController(text: widget.finding.bodyRegion);
    _textController = TextEditingController(text: widget.finding.text);
  }

  @override
  void dispose() {
    _regionController.dispose();
    _textController.dispose();
    super.dispose();
  }

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
          const Text('Edit Finding',
              style: TextStyle(
                  fontSize: 18, fontWeight: FontWeight.w600)),
          const SizedBox(height: 20),
          TextField(
            controller: _regionController,
            decoration: const InputDecoration(labelText: 'Body Region'),
            textCapitalization: TextCapitalization.words,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _textController,
            decoration: const InputDecoration(labelText: 'Finding'),
            maxLines: 4,
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop(
                widget.finding.copyWith(
                  bodyRegion: _regionController.text.trim(),
                  text: _textController.text.trim(),
                ),
              );
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}
