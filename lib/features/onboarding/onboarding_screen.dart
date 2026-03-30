import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import '../../../app/theme/app_theme.dart';
import '../../../core/auth/auth_service.dart';
import '../../../core/models/user_role.dart';
import '../../../core/services/analytics_service.dart';
import '../../../shared/widgets/loading_overlay.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Logo
            Expanded(
              flex: 5,
              child: Align(
                alignment: const Alignment(0, 0.5),
                child: Image.asset(
                  'assets/images/SMALL-Resolara_V5.png',
                  height: 160,
                  width:  160,
                  fit:    BoxFit.contain,
                  errorBuilder: (_, __, ___) => const SizedBox(),
                ),
              ),
            ),

            // Tab bar
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 32),
              decoration: BoxDecoration(
                color:        AppTheme.sage.withAlpha(20),
                borderRadius: BorderRadius.circular(12),
              ),
              child: TabBar(
                controller:       _tabs,
                indicatorSize:    TabBarIndicatorSize.tab,
                indicator:        BoxDecoration(
                  color:        AppTheme.emerald,
                  borderRadius: BorderRadius.circular(10),
                ),
                labelColor:       AppTheme.warmStone,
                unselectedLabelColor: AppTheme.textSecondary,
                labelStyle: const TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w600),
                tabs: const [
                  Tab(text: 'Practitioner'),
                  Tab(text: 'Patient'),
                ],
              ),
            ),

            // Forms
            Expanded(
              flex: 6,
              child: TabBarView(
                controller: _tabs,
                children: const [
                  _PractitionerForm(),
                  _PatientForm(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Practitioner tab ──────────────────────────────────────────────────────────

class _PractitionerForm extends StatefulWidget {
  const _PractitionerForm();

  @override
  State<_PractitionerForm> createState() => _PractitionerFormState();
}

class _PractitionerFormState extends State<_PractitionerForm> {
  final _auth = AuthService();

  Future<void> _activate() async {
    await _auth.saveToken('local-practitioner');
    await _auth.saveRole(UserRole.practitioner);
    Analytics.practitionerActivated();
    if (mounted) context.go('/home');
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 24, 32, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ElevatedButton(
            onPressed: _activate,
            child: const Text('Enter as Practitioner'),
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
    );
  }
}

// ── Patient tab ───────────────────────────────────────────────────────────────

class _PatientForm extends StatefulWidget {
  const _PatientForm();

  @override
  State<_PatientForm> createState() => _PatientFormState();
}

class _PatientFormState extends State<_PatientForm> {
  final _controller = TextEditingController();
  final _auth       = AuthService();
  bool    _loading  = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _enter() async {
    final email = _controller.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      setState(() => _error = 'Please enter a valid email address.');
      return;
    }
    setState(() { _loading = true; _error = null; });
    // Generate a local token — no server call needed until email auth is live.
    final token = const Uuid().v4();
    await _auth.saveToken(token);
    await _auth.savePatientEmail(email);
    await _auth.saveRole(UserRole.patient);
    Analytics.patientSignedUp();
    if (mounted) context.go('/patient');
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(32, 24, 32, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller:  _controller,
                decoration:  InputDecoration(
                  labelText: 'Email address',
                  errorText: _error,
                ),
                keyboardType:     TextInputType.emailAddress,
                autocorrect:      false,
                onSubmitted:      (_) => _enter(),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _loading ? null : _enter,
                child: const Text('Continue'),
              ),
              const Spacer(),
              const Text(
                'Free for patients.\nYour doctor\'s results will appear here.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
        if (_loading) const LoadingOverlay(message: 'Signing in…'),
      ],
    );
  }
}

