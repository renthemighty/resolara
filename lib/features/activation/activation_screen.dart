import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../app/theme/app_theme.dart';
import '../../../core/auth/auth_service.dart';
import '../../../shared/widgets/loading_overlay.dart';

class ActivationScreen extends StatefulWidget {
  const ActivationScreen({super.key});

  @override
  State<ActivationScreen> createState() => _ActivationScreenState();
}

class _ActivationScreenState extends State<ActivationScreen> {
  final _controller = TextEditingController();
  final _auth = AuthService();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _activate() async {
    final code = _controller.text.trim();
    if (code.isEmpty) {
      setState(() => _error = 'Please enter your activation code.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      // TODO: validate code against Resolara backend
      await _auth.saveActivationCode(code);
      if (mounted) context.go('/home');
    } catch (e) {
      setState(() => _error = 'Activation failed. Please check your code and try again.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Scaffold(
          backgroundColor: AppTheme.background,
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Spacer(),
                  const Text(
                    'Resolara',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Clinical Visualization',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppTheme.textSecondary, fontSize: 16),
                  ),
                  const Spacer(),
                  TextField(
                    controller: _controller,
                    decoration: InputDecoration(
                      labelText: 'Activation Code',
                      hintText: 'Enter your practice activation code',
                      errorText: _error,
                    ),
                    keyboardType: TextInputType.text,
                    textCapitalization: TextCapitalization.characters,
                    onSubmitted: (_) => _activate(),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _loading ? null : _activate,
                    child: const Text('Activate'),
                  ),
                  const Spacer(),
                  const Text(
                    'For licensed healthcare professionals only.\nNot for diagnostic use.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ),
        if (_loading) const LoadingOverlay(message: 'Activating…'),
      ],
    );
  }
}
