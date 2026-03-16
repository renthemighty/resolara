import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_svg/flutter_svg.dart';
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
      // DEV: accept hardcoded test code
      if (code != '1234567890') {
        setState(() {
          _error = 'Activation failed. Please check your code and try again.';
          _loading = false;
        });
        return;
      }
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
          body: SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Logo — top portion of screen
                Expanded(
                  flex: 6,
                  child: Align(
                    alignment: const Alignment(0, 0.5),
                    child: Image.asset(
                      'assets/images/SMALL-Resolara_V5.png',
                      height: 180,
                      width: 180,
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) => const SizedBox(),
                    ),
                  ),
                ),
                // Form — bottom portion
                Expanded(
                  flex: 5,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(32, 0, 32, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'Clinical Visualization',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurface.withAlpha(153),
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 24),
                        TextField(
                          controller: _controller,
                          decoration: InputDecoration(
                            labelText: 'Activation Code',
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
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (_loading) const LoadingOverlay(message: 'Activating…'),
      ],
    );
  }
}
