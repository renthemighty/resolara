import 'package:dio/dio.dart';

import 'clinic_api_client.dart';

export 'clinic_api_client.dart' show ClinicApiClient;

enum AuthResult { ok, mfaRequired, invalidCredentials, throttled, error }

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

class ClinicAuthService {
  ClinicAuthService._();
  static final ClinicAuthService instance = ClinicAuthService._();

  Dio get _dio => ClinicApiClient.instance.raw;

  Future<({AuthResult result, ClinicUser? user, String? errorDetail, int? retryAfter})> login(
    String email,
    String password, {
    bool rememberMe = false,
  }) async {
    try {
      final res = await _dio.post('/v1/clinic/auth/login', data: {
        'email': email,
        'password': password,
        'remember_me': rememberMe,
      });
      final status = res.statusCode ?? 0;
      final body = (res.data is Map<String, dynamic>)
          ? res.data as Map<String, dynamic>
          : <String, dynamic>{};

      if (status == 200) {
        final kind = body['status'] as String?;
        final token = body['token'] as String?;
        if (token != null) ClinicApiClient.setToken(token, persist: rememberMe);
        if (kind == 'mfa_required') {
          return (result: AuthResult.mfaRequired, user: null, errorDetail: null, retryAfter: null);
        }
        if (kind == 'ok') {
          final u = body['user'] as Map<String, dynamic>?;
          return (
            result: AuthResult.ok,
            user: u != null ? ClinicUser.fromJson(u) : null,
            errorDetail: null,
            retryAfter: null,
          );
        }
      }
      if (status == 401) {
        return (result: AuthResult.invalidCredentials, user: null, errorDetail: null, retryAfter: null);
      }
      if (status == 429) {
        return (
          result: AuthResult.throttled,
          user: null,
          errorDetail: null,
          retryAfter: (body['retry_after'] as int?) ?? 900,
        );
      }
      return (
        result: AuthResult.error,
        user: null,
        errorDetail: 'HTTP $status: ${body['error'] ?? res.data}',
        retryAfter: null,
      );
    } on DioException catch (e) {
      final detail = 'DioException ${e.type.name}: ${e.message ?? e.error}';
      return (result: AuthResult.error, user: null, errorDetail: detail, retryAfter: null);
    } catch (e) {
      return (result: AuthResult.error, user: null, errorDetail: '$e', retryAfter: null);
    }
  }

  Future<({AuthResult result, ClinicUser? user})> verifyMfa(String code) async {
    try {
      final res = await _dio.post('/v1/clinic/auth/mfa-verify', data: {'code': code});
      final status = res.statusCode ?? 0;
      final body = (res.data is Map<String, dynamic>)
          ? res.data as Map<String, dynamic>
          : <String, dynamic>{};
      if (status == 200 && body['status'] == 'ok') {
        final u = body['user'] as Map<String, dynamic>?;
        return (result: AuthResult.ok, user: u != null ? ClinicUser.fromJson(u) : null);
      }
      if (status == 401) {
        return (result: AuthResult.invalidCredentials, user: null);
      }
      return (result: AuthResult.error, user: null);
    } on DioException {
      return (result: AuthResult.error, user: null);
    }
  }

  Future<({ClinicUser? user, ClinicInfo? clinic})> me() async {
    try {
      final res = await _dio.get('/v1/clinic/auth/me');
      if ((res.statusCode ?? 0) != 200) return (user: null, clinic: null);
      final body = res.data as Map<String, dynamic>;
      return (
        user: ClinicUser.fromJson(body['user'] as Map<String, dynamic>),
        clinic: ClinicInfo.fromJson(body['clinic'] as Map<String, dynamic>),
      );
    } on DioException {
      return (user: null, clinic: null);
    }
  }

  Future<void> logout() async {
    try {
      await _dio.post('/v1/clinic/auth/logout');
    } catch (_) {}
    ClinicApiClient.clearToken();
  }
}
