import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_theme.dart';
import '../services/clinic_api_client.dart';
import '../widgets/web_shell.dart';

/// Patient list with Cmd/Ctrl-K search.
///
/// Fetches from GET /v1/clinic/patients?q=<search>&limit=20. The backend
/// uses blind-index prefix matching on envelope-encrypted patient names.
/// No substring search — practitioners type the start of a name.
class PatientsScreen extends ConsumerStatefulWidget {
  const PatientsScreen({super.key});

  @override
  ConsumerState<PatientsScreen> createState() => _PatientsScreenState();
}

class _PatientsScreenState extends ConsumerState<PatientsScreen> {
  final _searchController = TextEditingController();
  final _searchFocus = FocusNode();
  Timer? _debounce;
  List<Map<String, dynamic>> _patients = [];
  int _total = 0;
  bool _loading = true;
  String? _error;
  bool _showAddForm = false;

  @override
  void initState() {
    super.initState();
    _loadPatients();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocus.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _loadPatients({String query = ''}) async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final dio = ClinicApiClient.instance.raw;
      final params = <String, dynamic>{'limit': 50};
      if (query.length >= 2) params['q'] = query;

      final res = await dio.get('/v1/clinic/patients', queryParameters: params);
      if (!mounted) return;

      if ((res.statusCode ?? 0) == 200) {
        final body = res.data as Map<String, dynamic>;
        setState(() {
          _patients = List<Map<String, dynamic>>.from(body['patients'] as List);
          _total = (body['total'] as int?) ?? _patients.length;
          _loading = false;
        });
      } else {
        setState(() {
          _loading = false;
          _error = (res.data as Map<String, dynamic>?)?['error'] as String? ?? 'Failed to load';
        });
      }
    } on DioException catch (e) {
      if (mounted) setState(() { _loading = false; _error = 'Network error: ${e.message}'; });
    }
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      _loadPatients(query: value.trim());
    });
  }

  Future<void> _createPatient(String firstName, String lastName, String? dob, String? email) async {
    try {
      final dio = ClinicApiClient.instance.raw;
      final res = await dio.post('/v1/clinic/patients', data: {
        'first_name': firstName,
        'last_name': lastName,
        if (dob != null && dob.isNotEmpty) 'dob': dob,
        if (email != null && email.isNotEmpty) 'email': email,
      });
      if (!mounted) return;
      if ((res.statusCode ?? 0) == 201) {
        setState(() => _showAddForm = false);
        _loadPatients(query: _searchController.text.trim());
      } else {
        final body = res.data as Map<String, dynamic>? ?? {};
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(body['error'] as String? ?? 'Failed to create patient')),
        );
      }
    } on DioException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.message}')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyK, meta: true): () => _searchFocus.requestFocus(),
        const SingleActivator(LogicalKeyboardKey.keyK, control: true): () => _searchFocus.requestFocus(),
      },
      child: Focus(
        autofocus: true,
        child: WebShell(
          title: 'Patients',
          body: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header row
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        focusNode: _searchFocus,
                        onChanged: _onSearchChanged,
                        style: const TextStyle(color: AppTheme.warmStone, fontSize: 14),
                        decoration: InputDecoration(
                          hintText: 'Search by patient name... (${_shortcutLabel})',
                          hintStyle: TextStyle(color: AppTheme.sage.withValues(alpha: 0.6)),
                          prefixIcon: const Icon(Icons.search, color: AppTheme.sage, size: 20),
                          suffixIcon: _searchController.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.close, size: 18, color: AppTheme.sage),
                                  onPressed: () {
                                    _searchController.clear();
                                    _loadPatients();
                                  },
                                )
                              : null,
                          filled: true,
                          fillColor: const Color(0xFF122B21),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide.none,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: Color(0xFF1D3A31)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: AppTheme.gold, width: 2),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    ElevatedButton.icon(
                      onPressed: () => setState(() => _showAddForm = !_showAddForm),
                      icon: const Icon(Icons.person_add_outlined, size: 18),
                      label: const Text('Add patient'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.gold,
                        foregroundColor: AppTheme.forestTeal,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Add patient form
                if (_showAddForm) _AddPatientForm(
                  onSubmit: _createPatient,
                  onCancel: () => setState(() => _showAddForm = false),
                ),

                // Error
                if (_error != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF3A1E1E),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(_error!, style: const TextStyle(color: Color(0xFFCF6679), fontSize: 13)),
                  ),
                  const SizedBox(height: 12),
                ],

                // Count
                Text(
                  '$_total patients',
                  style: TextStyle(fontFamily: AppTheme.fontFamily, fontSize: 12, color: AppTheme.sage),
                ),
                const SizedBox(height: 8),

                // Patient list
                Expanded(
                  child: _loading
                      ? const Center(child: CircularProgressIndicator(color: AppTheme.gold))
                      : _patients.isEmpty
                          ? Center(
                              child: Text(
                                _searchController.text.isNotEmpty
                                    ? 'No patients match your search'
                                    : 'No patients yet',
                                style: TextStyle(color: AppTheme.sage, fontSize: 14),
                              ),
                            )
                          : ListView.builder(
                              itemCount: _patients.length,
                              itemBuilder: (context, i) => _PatientRow(patient: _patients[i]),
                            ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String get _shortcutLabel {
    final isMac = Theme.of(context).platform == TargetPlatform.macOS;
    return isMac ? '\u2318K' : 'Ctrl+K';
  }
}

class _PatientRow extends StatelessWidget {
  const _PatientRow({required this.patient});
  final Map<String, dynamic> patient;

  @override
  Widget build(BuildContext context) {
    final first = patient['first_name'] as String? ?? '';
    final last = patient['last_name'] as String? ?? '';
    final dob = patient['dob'] as String?;
    final email = patient['email'] as String?;
    final vendor = patient['emr_vendor'] as String? ?? 'manual';

    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF122B21),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF1D3A31)),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        title: Text(
          '$first $last',
          style: const TextStyle(
            fontFamily: AppTheme.fontFamily,
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppTheme.warmStone,
          ),
        ),
        subtitle: Text(
          [
            if (dob != null && dob.isNotEmpty) 'DOB $dob',
            if (email != null && email.isNotEmpty) email,
            if (vendor != 'manual') vendor.toUpperCase(),
          ].join(' · '),
          style: const TextStyle(fontSize: 12, color: AppTheme.sage),
        ),
        trailing: const Icon(Icons.chevron_right, color: AppTheme.sage, size: 20),
        onTap: () {
          // TODO(patient-detail): navigate to patient detail page
        },
      ),
    );
  }
}

class _AddPatientForm extends StatefulWidget {
  const _AddPatientForm({required this.onSubmit, required this.onCancel});

  final Future<void> Function(String firstName, String lastName, String? dob, String? email) onSubmit;
  final VoidCallback onCancel;

  @override
  State<_AddPatientForm> createState() => _AddPatientFormState();
}

class _AddPatientFormState extends State<_AddPatientForm> {
  final _firstCtrl = TextEditingController();
  final _lastCtrl = TextEditingController();
  final _dobCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _firstCtrl.dispose();
    _lastCtrl.dispose();
    _dobCtrl.dispose();
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_firstCtrl.text.trim().isEmpty || _lastCtrl.text.trim().isEmpty) return;
    setState(() => _submitting = true);
    await widget.onSubmit(
      _firstCtrl.text.trim(),
      _lastCtrl.text.trim(),
      _dobCtrl.text.trim().isEmpty ? null : _dobCtrl.text.trim(),
      _emailCtrl.text.trim().isEmpty ? null : _emailCtrl.text.trim(),
    );
    if (mounted) setState(() => _submitting = false);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF122B21),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.gold.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'New patient',
            style: TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppTheme.warmStone,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _field(_firstCtrl, 'First name *')),
              const SizedBox(width: 12),
              Expanded(child: _field(_lastCtrl, 'Last name *')),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: _field(_dobCtrl, 'DOB (YYYY-MM-DD)')),
              const SizedBox(width: 12),
              Expanded(child: _field(_emailCtrl, 'Email')),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: _submitting ? null : widget.onCancel,
                child: const Text('Cancel', style: TextStyle(color: AppTheme.sage)),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: _submitting ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.gold,
                  foregroundColor: AppTheme.forestTeal,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: _submitting
                    ? const SizedBox(
                        width: 16, height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.forestTeal),
                      )
                    : const Text('Create'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _field(TextEditingController ctrl, String label) {
    return TextField(
      controller: ctrl,
      enabled: !_submitting,
      style: const TextStyle(color: AppTheme.warmStone, fontSize: 13),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: AppTheme.sage, fontSize: 12),
        filled: true,
        fillColor: const Color(0xFF0A1F1C),
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: Color(0xFF1D3A31)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: AppTheme.gold),
        ),
      ),
    );
  }
}
