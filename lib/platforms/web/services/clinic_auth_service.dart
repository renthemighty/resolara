import 'package:dio/dio.dart';

import 'clinic_api_client.dart';

/// Return states from [ClinicAuthService.login] and [verifyMfa].
enum AuthResult { ok, mfaRequired, invalidCredentials, throttled, error }

/// Lightweight model for the authenticated user returned by the backend.
class ClinicUser {
  const ClinicUser({
    required this.id,
    required this.email,
    required this.role,
    required this.clinicId,
    this.totpEnabled = false,
  });

  final String id;
  final String email;
  final String role;
  final String clinicId;
  final bool totpEnabled;

  factory ClinicUser.fromJson(Map<String, dynamic> json) => ClinicUser(
        id: json['id'] as String,
        email: json['email'] as String,
        role: json['role'] as String,
        clinicId: json['clinic_id'] as String,
        totpEnabled: (json['totp_enabled'] as bool?) ?? false,
      );
}

class ClinicInfo {
  const ClinicInfo({
    required this.id,
    required this.tier,
    required this.maxPractitioners,
    required this.maxPatients,
    required this.maxStorageGb,
  });

  final String id;
  final String tier;
  final int maxPractitioners;
  final int maxPatients;
  final int maxStorageGb;

  factory ClinicInfo.fromJson(Map<String, dynamic> json) => ClinicInfo(
        id: json['id'] as String,
        tier: json['tier'] as String,
        maxPractitioners: json['max_practitioners'] as int,
        maxPatients: json['max_patients'] as int,
        maxStorageGb: json['max_storage_gb'] as int,
      );
}

/// Auth layer for the clinic web app.
///
/// All cookie handling happens in the browser — we never touch
/// Set-Cookie headers directly. The backend sets the `resolara_session`
/// (httpOnly) and `resolara_csrf` cookies; the CSRF token is read by the
/// Dio interceptor and echoed back in `X-CSRF-Token`.
class ClinicAuthService {
  ClinicAuthService(this._dio);

  final Dio _dio;

  static ClinicAuthService get instance =>
      ClinicAuthService(ClinicApiClient.instance.raw);

  /// POST /v1/clinic/auth/login — returns one of:
  ///   AuthResult.ok           — session created, [user] populated
  ///   AuthResult.mfaRequired  — TOTP challenge pending, no user yet
  ///   AuthResult.invalidCredentials
  ///   AuthResult.throttled    — too many failed attempts
  ///   AuthResult.error        — network / server failure
  Future<({AuthResult result, ClinicUser? user, int? retryAfter})> login(
    String email,
    String password,
  ) async {
    try {
      final res = await _dio.post('/v1/clinic/auth/login', data: {
        'email': email,
        'password': password,
      });
      final status = res.statusCode ?? 0;
      final body = (res.data as Map<String, dynamic>?) ?? {};

      if (status == 200) {
        final kind = body['status'] as String?;
        if (kind == 'mfa_required') {
          return (result: AuthResult.mfaRequired, user: null, retryAfter: null);
        }
        if (kind == 'ok') {
          final u = body['user'] as Map<String, dynamic>?;
          return (
            result: AuthResult.ok,
            user: u != null ? ClinicUser.fromJson(u) : null,
            retryAfter: null,
          );
        }
      }
      if (status == 401) {
        return (result: AuthResult.invalidCredentials, user: null, retryAfter: null);
      }
      if (status == 429) {
        return (
          result: AuthResult.throttled,
          user: null,
          retryAfter: (body['retry_after'] as int?) ?? 900,
        );
      }
      return (result: AuthResult.error, user: null, retryAfter: null);
    } on DioException {
      return (result: AuthResult.error, user: null, retryAfter: null);
    }
  }

  /// POST /v1/clinic/auth/mfa-verify — call after login returns
  /// `mfaRequired`. Requires the pending-MFA session cookie set by the
  /// preceding login call.
  Future<({AuthResult result, ClinicUser? user})> verifyMfa(String code) async {
    try {
      final res = await _dio.post('/v1/clinic/auth/mfa-verify', data: {'code': code});
      final status = res.statusCode ?? 0;
      final body = (res.data as Map<String, dynamic>?) ?? {};
      if (status == 200 && body['status'] == 'ok') {
        final u = body['user'] as Map<String, dynamic>?;
        return (
          result: AuthResult.ok,
          user: u != null ? ClinicUser.fromJson(u) : null,
        );
      }
      if (status == 401) {
        return (result: AuthResult.invalidCredentials, user: null);
      }
      return (result: AuthResult.error, user: null);
    } on DioException {
      return (result: AuthResult.error, user: null);
    }
  }

  /// GET /v1/clinic/auth/me — used on app boot to check whether the
  /// session cookie the browser already has is still valid.
  Future<({ClinicUser? user, ClinicInfo? clinic})> me() async {
    try {
      final res = await _dio.get('/v1/clinic/auth/me');
      if ((res.statusCode ?? 0) != 200) {
        return (user: null, clinic: null);
      }
      final body = res.data as Map<String, dynamic>;
      return (
        user: ClinicUser.fromJson(body['user'] as Map<String, dynamic>),
        clinic: ClinicInfo.fromJson(body['clinic'] as Map<String, dynamic>),
      );
    } on DioException {
      return (user: null, clinic: null);
    }
  }

  /// POST /v1/clinic/auth/logout — ends the session server-side and
  /// expires both cookies.
  Future<void> logout() async {
    try {
      await _dio.post('/v1/clinic/auth/logout');
    } on DioException {
      // Non-fatal — cookies expire client-side anyway
    }
  }
}
