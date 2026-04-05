import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'clinic_auth_service.dart';

/// Authentication state for the clinic web app.
sealed class ClinicAuthState {
  const ClinicAuthState();
}

class AuthUnknown extends ClinicAuthState {
  const AuthUnknown();
}

class AuthLoggedOut extends ClinicAuthState {
  const AuthLoggedOut();
}

class AuthMfaPending extends ClinicAuthState {
  const AuthMfaPending();
}

class AuthLoggedIn extends ClinicAuthState {
  const AuthLoggedIn({required this.user, this.clinic});
  final ClinicUser user;
  final ClinicInfo? clinic;
}

/// Provider exposing the current auth state. The router listens to this
/// and redirects to /login when logged out, to / when logged in.
final clinicAuthProvider =
    StateNotifierProvider<ClinicAuthNotifier, ClinicAuthState>((ref) {
  final notifier = ClinicAuthNotifier(ClinicAuthService.instance);
  notifier.refresh();
  return notifier;
});

class ClinicAuthNotifier extends StateNotifier<ClinicAuthState> {
  ClinicAuthNotifier(this._auth) : super(const AuthUnknown());

  final ClinicAuthService _auth;

  /// Call /me on app boot to see if the browser already has a valid session.
  Future<void> refresh() async {
    final result = await _auth.me();
    if (result.user != null) {
      state = AuthLoggedIn(user: result.user!, clinic: result.clinic);
    } else {
      state = const AuthLoggedOut();
    }
  }

  /// Attempt to log in. If backend returns mfa_required, state transitions
  /// to AuthMfaPending and caller should collect the TOTP code.
  Future<({AuthResult result, int? retryAfter})> login(
    String email,
    String password,
  ) async {
    final r = await _auth.login(email, password);
    switch (r.result) {
      case AuthResult.ok:
        state = AuthLoggedIn(user: r.user!);
      case AuthResult.mfaRequired:
        state = const AuthMfaPending();
      case AuthResult.invalidCredentials:
      case AuthResult.throttled:
      case AuthResult.error:
        state = const AuthLoggedOut();
    }
    return (result: r.result, retryAfter: r.retryAfter);
  }

  Future<AuthResult> verifyMfa(String code) async {
    final r = await _auth.verifyMfa(code);
    if (r.result == AuthResult.ok) {
      state = AuthLoggedIn(user: r.user!);
    }
    return r.result;
  }

  Future<void> logout() async {
    await _auth.logout();
    state = const AuthLoggedOut();
  }
}
