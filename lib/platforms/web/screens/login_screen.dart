import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_theme.dart';

/// Clinic practitioner / admin login screen.
///
/// Three-step flow:
///   1. Email + password
///   2. If account has TOTP enabled, backend returns `mfa_required` and this
///      screen swaps to show a 6-digit code field
///   3. On success, backend sets httpOnly session cookie on `.resolara.ai`
///      and returns the CSRF token; we navigate to the dashboard
///
/// Auth service wiring lands with the PHP auth endpoints. For Milestone A
/// scaffolding, the form collects credentials and posts to a stub auth
/// endpoint.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _totpController = TextEditingController();

  bool _showTotp = false;
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _totpController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _submitting = true;
      _error = null;
    });

    // TODO(web-auth): POST /api/auth/login with email + password.
    // If response is { status: "mfa_required" }: set _showTotp = true and
    // ask for the code; re-submit with totp field populated. On success,
    // the session cookie will be set by the server (Domain=.resolara.ai,
    // httpOnly, Secure, SameSite=Lax) and the CSRF token will come back in
    // the JSON body. Save CSRF token in a Riverpod provider for later
    // X-CSRF-Token header on mutating requests.
    await Future.delayed(const Duration(milliseconds: 600));

    if (!mounted) return;
    setState(() {
      _submitting = false;
      _error = 'Auth backend not connected yet';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.forestTeal,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 48),
                  Text(
                    'Resolara Clinic',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: 32,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.warmStone,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Sign in to your clinic account',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: 15,
                      color: AppTheme.sage,
                    ),
                  ),
                  const SizedBox(height: 48),

                  // Email
                  TextFormField(
                    controller: _emailController,
                    enabled: !_submitting && !_showTotp,
                    keyboardType: TextInputType.emailAddress,
                    autofillHints: const [AutofillHints.email],
                    style: const TextStyle(color: AppTheme.warmStone),
                    decoration: _inputDecoration('Work email'),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'Email required';
                      if (!v.contains('@')) return 'Enter a valid email';
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // Password
                  TextFormField(
                    controller: _passwordController,
                    enabled: !_submitting && !_showTotp,
                    obscureText: true,
                    autofillHints: const [AutofillHints.password],
                    style: const TextStyle(color: AppTheme.warmStone),
                    decoration: _inputDecoration('Password'),
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Password required';
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // TOTP (only when mfa_required came back)
                  if (_showTotp) ...[
                    TextFormField(
                      controller: _totpController,
                      enabled: !_submitting,
                      keyboardType: TextInputType.number,
                      autofillHints: const [AutofillHints.oneTimeCode],
                      maxLength: 6,
                      style: const TextStyle(
                        color: AppTheme.warmStone,
                        fontSize: 22,
                        letterSpacing: 8,
                      ),
                      decoration: _inputDecoration('6-digit code').copyWith(
                        counterText: '',
                      ),
                      validator: (v) {
                        if (v == null || v.length != 6) return 'Enter 6 digits';
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Error banner
                  if (_error != null) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF3A1E1E),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: const Color(0xFFCF6679),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.error_outline,
                            color: Color(0xFFCF6679),
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _error!,
                              style: const TextStyle(
                                color: Color(0xFFCF6679),
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Submit button
                  ElevatedButton(
                    onPressed: _submitting ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.gold,
                      foregroundColor: AppTheme.forestTeal,
                      minimumSize: const Size(double.infinity, 52),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: _submitting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: AppTheme.forestTeal,
                            ),
                          )
                        : Text(
                            _showTotp ? 'Verify code' : 'Sign in',
                            style: const TextStyle(
                              fontFamily: AppTheme.fontFamily,
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),
                  const SizedBox(height: 24),

                  // Skip to dashboard (dev only — remove once auth wired)
                  TextButton(
                    onPressed: () => context.go('/'),
                    child: const Text(
                      'Skip to dashboard (dev)',
                      style: TextStyle(
                        color: AppTheme.sage,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: AppTheme.sage),
      filled: true,
      fillColor: const Color(0xFF122B21),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFF1D3A31), width: 1),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppTheme.gold, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    );
  }
}
