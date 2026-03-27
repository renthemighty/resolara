import 'package:flutter/material.dart';
import '../../app/theme/app_theme.dart';
import '../../core/api/medications_service.dart';
import '../../core/models/extraction_result.dart';
import '../../core/models/medication.dart';

class MedicationsReviewScreen extends StatefulWidget {
  final List<Finding> findings;

  const MedicationsReviewScreen({super.key, required this.findings});

  @override
  State<MedicationsReviewScreen> createState() =>
      _MedicationsReviewScreenState();
}

class _MedicationsReviewScreenState extends State<MedicationsReviewScreen> {
  final _service   = MedicationsService();
  final _addController = TextEditingController();
  final _addFocus  = FocusNode();

  List<MedicationEntry> _entries = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _addController.dispose();
    _addFocus.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final meds = await _service.fetchSuggestions(widget.findings);
      setState(() {
        _entries = meds.map((m) => MedicationEntry(medication: m)).toList();
        _loading = false;
      });
    } on MedicationsServiceException catch (e) {
      setState(() { _error = e.message; _loading = false; });
    } catch (e) {
      setState(() { _error = 'Could not load medication suggestions.'; _loading = false; });
    }
  }

  void _toggleEntry(int i) {
    setState(() => _entries[i].active = !_entries[i].active);
  }

  void _toggleTime(int i, DoseTime t) {
    setState(() {
      if (_entries[i].times.contains(t)) {
        if (_entries[i].times.length > 1) _entries[i].times.remove(t);
      } else {
        _entries[i].times.add(t);
      }
    });
  }

  void _addMedication() {
    final name = _addController.text.trim();
    if (name.isEmpty) return;
    setState(() {
      _entries.add(MedicationEntry(
        medication: Medication(
          id:           'custom_${DateTime.now().millisecondsSinceEpoch}',
          name:         name,
          purpose:      'Added by practitioner.',
          typicalDosing: '',
          aiSuggested:  false,
        ),
      ));
      _addController.clear();
    });
    _addFocus.unfocus();
  }

  void _confirm() {
    final active = _entries.where((e) => e.active).toList();
    Navigator.of(context).pop(active);
  }

  @override
  Widget build(BuildContext context) {
    final activeCount = _entries.where((e) => e.active).length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Medications'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: _loading
          ? const _LoadingView()
          : _error != null
              ? _ErrorView(message: _error!, onRetry: _load)
              : Column(
                  children: [
                    Expanded(
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                        children: [
                          const Padding(
                            padding: EdgeInsets.only(bottom: 16, left: 2),
                            child: Text(
                              'Review and adjust the suggested medications. '
                              'Remove any that do not apply and add your own.',
                              style: TextStyle(
                                  fontSize: 13,
                                  color: AppTheme.textSecondary),
                            ),
                          ),
                          ..._entries.asMap().entries.map(
                                (e) => Padding(
                                  padding:
                                      const EdgeInsets.only(bottom: 10),
                                  child: _MedicationCard(
                                    entry: e.value,
                                    onToggle: () => _toggleEntry(e.key),
                                    onToggleTime: (t) =>
                                        _toggleTime(e.key, t),
                                  ),
                                ),
                              ),
                          const SizedBox(height: 4),
                          _AddMedicationRow(
                            controller: _addController,
                            focusNode: _addFocus,
                            onAdd: _addMedication,
                          ),
                          const SizedBox(height: 16),
                        ],
                      ),
                    ),
                    _ConfirmBar(activeCount: activeCount, onConfirm: _confirm),
                  ],
                ),
    );
  }
}

// ── Medication card ───────────────────────────────────────────────────────────

class _MedicationCard extends StatelessWidget {
  final MedicationEntry entry;
  final VoidCallback onToggle;
  final void Function(DoseTime) onToggleTime;

  const _MedicationCard({
    required this.entry,
    required this.onToggle,
    required this.onToggleTime,
  });

  @override
  Widget build(BuildContext context) {
    final isDark    = Theme.of(context).brightness == Brightness.dark;
    final inactive  = !entry.active;
    final textColor = isDark ? AppTheme.warmStone : AppTheme.emerald;
    final dimColor  = textColor.withAlpha(inactive ? 80 : 255);

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 200),
      opacity: inactive ? 0.55 : 1.0,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: inactive
                ? AppTheme.sage.withAlpha(80)
                : isDark
                    ? const Color(0xFF1E4535)
                    : AppTheme.sage,
            width: 1,
          ),
          color: isDark
              ? const Color(0xFF122B21)
              : AppTheme.lightSurface,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Medication name — strikethrough when inactive
                      Text(
                        entry.medication.name,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: dimColor,
                          decoration: inactive
                              ? TextDecoration.lineThrough
                              : TextDecoration.none,
                          decorationColor: dimColor,
                        ),
                      ),
                      if (entry.medication.purpose.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(
                          entry.medication.purpose,
                          style: TextStyle(
                              fontSize: 12,
                              color: AppTheme.textSecondary
                                  .withAlpha(inactive ? 100 : 200),
                              decoration: inactive
                                  ? TextDecoration.lineThrough
                                  : TextDecoration.none,
                              decorationColor: AppTheme.textSecondary),
                        ),
                      ],
                      if (entry.medication.typicalDosing.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          entry.medication.typicalDosing,
                          style: TextStyle(
                              fontSize: 12,
                              color: AppTheme.gold
                                  .withAlpha(inactive ? 80 : 180),
                              fontWeight: FontWeight.w500),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                // Toggle button
                GestureDetector(
                  onTap: onToggle,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: inactive
                          ? AppTheme.sage.withAlpha(30)
                          : AppTheme.error.withAlpha(25),
                      border: Border.all(
                        color: inactive ? AppTheme.sage : AppTheme.error,
                        width: 1.5,
                      ),
                    ),
                    child: Icon(
                      inactive ? Icons.add : Icons.remove,
                      size: 16,
                      color: inactive ? AppTheme.sage : AppTheme.error,
                    ),
                  ),
                ),
              ],
            ),

            // Dose time chips — only when active
            if (entry.active) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 6,
                children: DoseTime.values.map((t) {
                  final on = entry.times.contains(t);
                  return GestureDetector(
                    onTap: () => onToggleTime(t),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 130),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        color: on
                            ? AppTheme.gold.withAlpha(30)
                            : Colors.transparent,
                        border: Border.all(
                          color: on
                              ? AppTheme.gold
                              : AppTheme.sage.withAlpha(120),
                          width: 1,
                        ),
                      ),
                      child: Text(
                        t.label,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: on
                              ? AppTheme.gold
                              : AppTheme.textSecondary,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Add medication row ────────────────────────────────────────────────────────

class _AddMedicationRow extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final VoidCallback onAdd;

  const _AddMedicationRow({
    required this.controller,
    required this.focusNode,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: controller,
            focusNode: focusNode,
            textCapitalization: TextCapitalization.words,
            style: const TextStyle(fontSize: 14),
            decoration: InputDecoration(
              hintText: 'Add medication…',
              hintStyle: const TextStyle(
                  fontSize: 14, color: AppTheme.textSecondary),
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide:
                    const BorderSide(color: AppTheme.sage),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(
                    color: AppTheme.sage, width: 1),
              ),
            ),
            onSubmitted: (_) => onAdd(),
          ),
        ),
        const SizedBox(width: 10),
        GestureDetector(
          onTap: onAdd,
          child: Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppTheme.gold.withAlpha(25),
              border: Border.all(color: AppTheme.gold, width: 1.5),
            ),
            child: const Icon(Icons.add,
                size: 20, color: AppTheme.gold),
          ),
        ),
      ],
    );
  }
}

// ── Confirm bar ───────────────────────────────────────────────────────────────

class _ConfirmBar extends StatelessWidget {
  final int activeCount;
  final VoidCallback onConfirm;

  const _ConfirmBar(
      {required this.activeCount, required this.onConfirm});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppTheme.surface,
        border:
            Border(top: BorderSide(color: AppTheme.sage, width: 0.5)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            activeCount == 0
                ? 'No medications selected'
                : '$activeCount medication${activeCount == 1 ? '' : 's'} included',
            textAlign: TextAlign.center,
            style: const TextStyle(
                fontSize: 13, color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 10),
          ElevatedButton(
            onPressed: onConfirm,
            child: const Text('Confirm Medications'),
          ),
        ],
      ),
    );
  }
}

// ── Loading / error states ────────────────────────────────────────────────────

class _LoadingView extends StatelessWidget {
  const _LoadingView();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(color: AppTheme.gold),
          SizedBox(height: 20),
          Text('Reviewing findings for medications…',
              style: TextStyle(
                  color: AppTheme.textSecondary, fontSize: 14)),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline,
                size: 48, color: AppTheme.error),
            const SizedBox(height: 16),
            Text(message,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppTheme.textSecondary)),
            const SizedBox(height: 24),
            ElevatedButton(
                onPressed: onRetry, child: const Text('Try Again')),
          ],
        ),
      ),
    );
  }
}
