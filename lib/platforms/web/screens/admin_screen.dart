import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_theme.dart';
import '../services/clinic_api_client.dart';
import '../widgets/web_shell.dart';

/// Clinic admin screen — manage practitioners (add, disable, change role).
/// Only visible to users with role='admin'.
class AdminScreen extends ConsumerStatefulWidget {
  const AdminScreen({super.key});

  @override
  ConsumerState<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends ConsumerState<AdminScreen> {
  List<Map<String, dynamic>> _practitioners = [];
  int _maxPractitioners = 0;
  bool _loading = true;
  String? _error;
  bool _showAddForm = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final dio = ClinicApiClient.instance.raw;
      final res = await dio.get('/v1/clinic/admin/practitioners');
      if (!mounted) return;
      if ((res.statusCode ?? 0) == 200) {
        final body = res.data as Map<String, dynamic>;
        setState(() {
          _practitioners = List<Map<String, dynamic>>.from(body['practitioners'] as List);
          _maxPractitioners = (body['max_practitioners'] as int?) ?? 0;
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

  Future<void> _createPractitioner(String email, String password, String role) async {
    try {
      final dio = ClinicApiClient.instance.raw;
      final res = await dio.post('/v1/clinic/admin/practitioners', data: {
        'email': email,
        'password': password,
        'role': role,
      });
      if (!mounted) return;
      if ((res.statusCode ?? 0) == 201) {
        setState(() => _showAddForm = false);
        _load();
      } else {
        final body = res.data as Map<String, dynamic>? ?? {};
        _showError(body['error'] as String? ?? 'Failed to create');
      }
    } on DioException catch (e) {
      if (mounted) _showError('Error: ${e.message}');
    }
  }

  Future<void> _toggleStatus(Map<String, dynamic> practitioner) async {
    final id = practitioner['id'] as String;
    final currentStatus = practitioner['status'] as String;
    final newStatus = currentStatus == 'active' ? 'disabled' : 'active';

    try {
      final dio = ClinicApiClient.instance.raw;
      final Response<dynamic> res;
      if (newStatus == 'disabled') {
        res = await dio.delete('/v1/clinic/admin/practitioners/$id');
      } else {
        res = await dio.put('/v1/clinic/admin/practitioners/$id', data: {'status': 'active'});
      }
      if (!mounted) return;
      if ((res.statusCode ?? 0) == 200) {
        _load();
      } else {
        final body = res.data as Map<String, dynamic>? ?? {};
        _showError(body['error'] as String? ?? 'Failed to update');
      }
    } on DioException catch (e) {
      if (mounted) _showError('Error: ${e.message}');
    }
  }

  Future<void> _changeRole(Map<String, dynamic> practitioner, String newRole) async {
    final id = practitioner['id'] as String;
    try {
      final dio = ClinicApiClient.instance.raw;
      final res = await dio.put('/v1/clinic/admin/practitioners/$id', data: {'role': newRole});
      if (!mounted) return;
      if ((res.statusCode ?? 0) == 200) {
        _load();
      } else {
        final body = res.data as Map<String, dynamic>? ?? {};
        _showError(body['error'] as String? ?? 'Failed to update role');
      }
    } on DioException catch (e) {
      if (mounted) _showError('Error: ${e.message}');
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: AppTheme.error),
    );
  }

  @override
  Widget build(BuildContext context) {
    final activeCount = _practitioners.where((p) => p['status'] == 'active').length;

    return WebShell(
      title: 'Clinic admin',
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            const Text(
              'Practitioners',
              style: TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppTheme.warmStone,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '$activeCount active of $_maxPractitioners allowed',
                  style: const TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: 12,
                    color: AppTheme.sage,
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () => setState(() => _showAddForm = !_showAddForm),
                  icon: const Icon(Icons.person_add_outlined, size: 18),
                  label: const Text('Add practitioner'),
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

            // Add form
            if (_showAddForm)
              _AddPractitionerForm(
                onSubmit: _createPractitioner,
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

            // Practitioner list
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator(color: AppTheme.gold))
                  : _practitioners.isEmpty
                      ? const Center(
                          child: Text('No practitioners', style: TextStyle(color: AppTheme.sage)),
                        )
                      : ListView.builder(
                          itemCount: _practitioners.length,
                          itemBuilder: (context, i) => _PractitionerRow(
                            practitioner: _practitioners[i],
                            onToggleStatus: () => _toggleStatus(_practitioners[i]),
                            onChangeRole: (role) => _changeRole(_practitioners[i], role),
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PractitionerRow extends StatelessWidget {
  const _PractitionerRow({
    required this.practitioner,
    required this.onToggleStatus,
    required this.onChangeRole,
  });

  final Map<String, dynamic> practitioner;
  final VoidCallback onToggleStatus;
  final ValueChanged<String> onChangeRole;

  @override
  Widget build(BuildContext context) {
    final email = practitioner['email'] as String? ?? '';
    final role = practitioner['role'] as String? ?? 'practitioner';
    final status = practitioner['status'] as String? ?? 'active';
    final mfa = practitioner['totp_enabled'] as bool? ?? false;
    final lastLogin = practitioner['last_login_at'] as String?;
    final isDisabled = status == 'disabled';

    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      decoration: BoxDecoration(
        color: isDisabled ? const Color(0xFF0D1F1A) : const Color(0xFF122B21),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isDisabled ? const Color(0xFF1A2520) : const Color(0xFF1D3A31),
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: CircleAvatar(
          radius: 18,
          backgroundColor: isDisabled
              ? AppTheme.sage.withValues(alpha: 0.2)
              : role == 'admin'
                  ? AppTheme.gold.withValues(alpha: 0.2)
                  : AppTheme.emerald.withValues(alpha: 0.3),
          child: Icon(
            role == 'admin' ? Icons.admin_panel_settings : Icons.person,
            size: 18,
            color: isDisabled
                ? AppTheme.sage.withValues(alpha: 0.5)
                : role == 'admin'
                    ? AppTheme.gold
                    : AppTheme.sage,
          ),
        ),
        title: Text(
          email,
          style: TextStyle(
            fontFamily: AppTheme.fontFamily,
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: isDisabled ? AppTheme.sage.withValues(alpha: 0.5) : AppTheme.warmStone,
          ),
        ),
        subtitle: Text(
          [
            role.toUpperCase(),
            if (isDisabled) 'DISABLED',
            if (mfa) 'MFA',
            if (lastLogin != null) 'Last login: $lastLogin',
          ].join(' · '),
          style: TextStyle(
            fontSize: 11,
            color: isDisabled ? AppTheme.sage.withValues(alpha: 0.3) : AppTheme.sage,
          ),
        ),
        trailing: PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert, color: AppTheme.sage, size: 20),
          color: const Color(0xFF122B21),
          onSelected: (value) {
            switch (value) {
              case 'toggle_status':
                onToggleStatus();
              case 'make_admin':
                onChangeRole('admin');
              case 'make_practitioner':
                onChangeRole('practitioner');
            }
          },
          itemBuilder: (context) => [
            PopupMenuItem(
              value: 'toggle_status',
              child: Row(
                children: [
                  Icon(
                    isDisabled ? Icons.check_circle_outline : Icons.block,
                    size: 16,
                    color: isDisabled ? AppTheme.gold : AppTheme.error,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    isDisabled ? 'Re-activate' : 'Disable',
                    style: const TextStyle(color: AppTheme.warmStone, fontSize: 13),
                  ),
                ],
              ),
            ),
            if (role == 'practitioner')
              const PopupMenuItem(
                value: 'make_admin',
                child: Row(
                  children: [
                    Icon(Icons.admin_panel_settings, size: 16, color: AppTheme.gold),
                    SizedBox(width: 8),
                    Text('Make admin', style: TextStyle(color: AppTheme.warmStone, fontSize: 13)),
                  ],
                ),
              ),
            if (role == 'admin')
              const PopupMenuItem(
                value: 'make_practitioner',
                child: Row(
                  children: [
                    Icon(Icons.person, size: 16, color: AppTheme.sage),
                    SizedBox(width: 8),
                    Text('Remove admin', style: TextStyle(color: AppTheme.warmStone, fontSize: 13)),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _AddPractitionerForm extends StatefulWidget {
  const _AddPractitionerForm({required this.onSubmit, required this.onCancel});

  final Future<void> Function(String email, String password, String role) onSubmit;
  final VoidCallback onCancel;

  @override
  State<_AddPractitionerForm> createState() => _AddPractitionerFormState();
}

class _AddPractitionerFormState extends State<_AddPractitionerForm> {
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  String _role = 'practitioner';
  bool _submitting = false;
  bool _showPassword = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_emailCtrl.text.trim().isEmpty || _passCtrl.text.isEmpty) return;
    setState(() => _submitting = true);
    await widget.onSubmit(_emailCtrl.text.trim(), _passCtrl.text, _role);
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
            'New practitioner',
            style: TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppTheme.warmStone,
            ),
          ),
          const SizedBox(height: 12),
          _field(_emailCtrl, 'Email *', TextInputType.emailAddress),
          const SizedBox(height: 10),
          TextField(
            controller: _passCtrl,
            enabled: !_submitting,
            obscureText: !_showPassword,
            style: const TextStyle(color: AppTheme.warmStone, fontSize: 13),
            decoration: InputDecoration(
              labelText: 'Password * (min 12 chars)',
              labelStyle: const TextStyle(color: AppTheme.sage, fontSize: 12),
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
              suffixIcon: IconButton(
                icon: Icon(
                  _showPassword ? Icons.visibility_off : Icons.visibility,
                  size: 18, color: AppTheme.sage,
                ),
                onPressed: () => setState(() => _showPassword = !_showPassword),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Text('Role:', style: TextStyle(color: AppTheme.sage, fontSize: 12)),
              const SizedBox(width: 12),
              ChoiceChip(
                label: const Text('Practitioner'),
                selected: _role == 'practitioner',
                onSelected: _submitting ? null : (_) => setState(() => _role = 'practitioner'),
                selectedColor: AppTheme.gold.withValues(alpha: 0.3),
                labelStyle: TextStyle(
                  color: _role == 'practitioner' ? AppTheme.gold : AppTheme.sage,
                  fontSize: 12,
                ),
                backgroundColor: const Color(0xFF0A1F1C),
                side: BorderSide(
                  color: _role == 'practitioner' ? AppTheme.gold : const Color(0xFF1D3A31),
                ),
              ),
              const SizedBox(width: 8),
              ChoiceChip(
                label: const Text('Admin'),
                selected: _role == 'admin',
                onSelected: _submitting ? null : (_) => setState(() => _role = 'admin'),
                selectedColor: AppTheme.gold.withValues(alpha: 0.3),
                labelStyle: TextStyle(
                  color: _role == 'admin' ? AppTheme.gold : AppTheme.sage,
                  fontSize: 12,
                ),
                backgroundColor: const Color(0xFF0A1F1C),
                side: BorderSide(
                  color: _role == 'admin' ? AppTheme.gold : const Color(0xFF1D3A31),
                ),
              ),
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

  Widget _field(TextEditingController ctrl, String label, [TextInputType? type]) {
    return TextField(
      controller: ctrl,
      enabled: !_submitting,
      keyboardType: type,
      style: const TextStyle(color: AppTheme.warmStone, fontSize: 13),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: AppTheme.sage, fontSize: 12),
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
