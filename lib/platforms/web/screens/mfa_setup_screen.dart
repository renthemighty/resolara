import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../app/theme/app_theme.dart';
import '../services/clinic_api_client.dart';
import '../widgets/web_shell.dart';

/// MFA enrollment screen — generates a TOTP secret, displays QR code for
/// authenticator app scanning, then confirms with a 6-digit code.
///
/// Flow:
///   1. POST /v1/clinic/auth/mfa-setup → get otpauth_uri + secret_b32
///   2. Display QR code + manual entry secret
///   3. User enters 6-digit code from their authenticator
///   4. POST /v1/clinic/auth/mfa-confirm → enables MFA on success
class MfaSetupScreen extends ConsumerStatefulWidget {
  const MfaSetupScreen({super.key});

  @override
  ConsumerState<MfaSetupScreen> createState() => _MfaSetupScreenState();
}

class _MfaSetupScreenState extends ConsumerState<MfaSetupScreen> {
  String? _otpauthUri;
  String? _secretB32;
  bool _loading = true;
  String? _error;

  final _codeCtrl = TextEditingController();
  bool _confirming = false;
  String? _confirmError;
  bool _done = false;

  @override
  void initState() {
    super.initState();
    _setup();
  }

  @override
  void dispose() {
    _codeCtrl.dispose();
    super.dispose();
  }

  Future<void> _setup() async {
    setState(() { _loading = true; _error = null; });
    try {
      final dio = ClinicApiClient.instance.raw;
      final res = await dio.post('/v1/clinic/auth/mfa-setup');
      if (!mounted) return;
      if ((res.statusCode ?? 0) == 200) {
        final body = res.data as Map<String, dynamic>;
        setState(() {
          _otpauthUri = body['otpauth_uri'] as String?;
          _secretB32 = body['secret_b32'] as String?;
          _loading = false;
        });
      } else {
        final body = res.data as Map<String, dynamic>? ?? {};
        setState(() {
          _loading = false;
          _error = body['error'] as String? ?? 'Failed to set up MFA';
        });
      }
    } on DioException catch (e) {
      if (mounted) setState(() { _loading = false; _error = 'Network error: ${e.message}'; });
    }
  }

  Future<void> _confirm() async {
    final code = _codeCtrl.text.trim();
    if (code.length != 6) {
      setState(() => _confirmError = 'Enter the 6-digit code from your authenticator');
      return;
    }
    setState(() { _confirming = true; _confirmError = null; });
    try {
      final dio = ClinicApiClient.instance.raw;
      final res = await dio.post('/v1/clinic/auth/mfa-confirm', data: {'code': code});
      if (!mounted) return;
      if ((res.statusCode ?? 0) == 200) {
        setState(() { _confirming = false; _done = true; });
      } else {
        final body = res.data as Map<String, dynamic>? ?? {};
        setState(() {
          _confirming = false;
          _confirmError = body['error'] as String? ?? 'Verification failed';
        });
      }
    } on DioException catch (e) {
      if (mounted) setState(() { _confirming = false; _confirmError = 'Error: ${e.message}'; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return WebShell(
      title: 'Set up MFA',
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: _loading
                ? const CircularProgressIndicator(color: AppTheme.gold)
                : _error != null
                    ? _errorView()
                    : _done
                        ? _doneView()
                        : _setupView(),
          ),
        ),
      ),
    );
  }

  Widget _errorView() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.error_outline, color: AppTheme.error, size: 48),
        const SizedBox(height: 16),
        Text(
          _error!,
          style: const TextStyle(color: AppTheme.error, fontSize: 14),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        OutlinedButton(
          onPressed: () => Navigator.of(context).pop(),
          style: OutlinedButton.styleFrom(foregroundColor: AppTheme.sage),
          child: const Text('Go back'),
        ),
      ],
    );
  }

  Widget _doneView() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.check_circle_outline, color: AppTheme.gold, size: 56),
        const SizedBox(height: 16),
        const Text(
          'MFA is now enabled',
          style: TextStyle(
            fontFamily: AppTheme.fontFamily,
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppTheme.warmStone,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'You will be asked for a code from your authenticator app each time you sign in.',
          style: TextStyle(color: AppTheme.sage, fontSize: 13),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        ElevatedButton(
          onPressed: () => Navigator.of(context).pop(),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.gold,
            foregroundColor: AppTheme.forestTeal,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          child: const Text('Done'),
        ),
      ],
    );
  }

  Widget _setupView() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Scan with your authenticator app',
            style: TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppTheme.warmStone,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          const Text(
            'Use Google Authenticator, Authy, 1Password, or any TOTP-compatible app.',
            style: TextStyle(color: AppTheme.sage, fontSize: 13),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),

          // QR code
          if (_otpauthUri != null)
            Center(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: QrImageView(
                  data: _otpauthUri!,
                  version: QrVersions.auto,
                  size: 200,
                  backgroundColor: Colors.white,
                ),
              ),
            ),
          const SizedBox(height: 16),

          // Manual entry
          if (_secretB32 != null) ...[
            const Text(
              'Or enter this key manually:',
              style: TextStyle(color: AppTheme.sage, fontSize: 12),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            InkWell(
              onTap: () {
                Clipboard.setData(ClipboardData(text: _secretB32!));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Secret copied to clipboard'),
                    duration: Duration(seconds: 2),
                  ),
                );
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFF122B21),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFF1D3A31)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      _secretB32!,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.warmStone,
                        letterSpacing: 1.5,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Icon(Icons.copy, size: 16, color: AppTheme.sage),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 32),

          // Confirm code
          const Text(
            'Enter the 6-digit code from your app to confirm:',
            style: TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: 14,
              color: AppTheme.warmStone,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _codeCtrl,
            autofocus: false,
            keyboardType: TextInputType.number,
            maxLength: 6,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: 'monospace',
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: AppTheme.warmStone,
              letterSpacing: 8,
            ),
            decoration: InputDecoration(
              counterText: '',
              hintText: '000000',
              hintStyle: TextStyle(color: AppTheme.sage.withValues(alpha: 0.3)),
              filled: true,
              fillColor: const Color(0xFF122B21),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Color(0xFF1D3A31)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AppTheme.gold, width: 2),
              ),
            ),
            onSubmitted: (_) => _confirm(),
          ),
          if (_confirmError != null) ...[
            const SizedBox(height: 8),
            Text(
              _confirmError!,
              style: const TextStyle(color: Color(0xFFCF6679), fontSize: 12),
              textAlign: TextAlign.center,
            ),
          ],
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              OutlinedButton(
                onPressed: _confirming ? null : () => Navigator.of(context).pop(),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.sage,
                  side: const BorderSide(color: Color(0xFF1D3A31)),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                ),
                child: const Text('Cancel'),
              ),
              const SizedBox(width: 12),
              ElevatedButton(
                onPressed: _confirming ? null : _confirm,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.gold,
                  foregroundColor: AppTheme.forestTeal,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: _confirming
                    ? const SizedBox(
                        width: 18, height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.forestTeal),
                      )
                    : const Text('Verify and enable MFA'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
