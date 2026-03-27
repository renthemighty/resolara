import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/user_role.dart';

class AuthService {
  static const _storage        = FlutterSecureStorage();
  static const _tokenKey       = 'resolara_device_token';
  static const _activationKey  = 'resolara_activation_code';
  static const _roleKey        = 'resolara_user_role';
  static const _emailKey       = 'resolara_patient_email';

  Future<String?> getToken() => _storage.read(key: _tokenKey);

  Future<void> saveToken(String token) =>
      _storage.write(key: _tokenKey, value: token);

  Future<void> clearToken() => _storage.delete(key: _tokenKey);

  Future<bool> isActivated() async {
    final token = await _storage.read(key: _tokenKey);
    return token != null && token.isNotEmpty;
  }

  // ── Role ────────────────────────────────────────────────────────────────────

  Future<UserRole> getRole() async {
    final raw = await _storage.read(key: _roleKey);
    return UserRoleX.fromJson(raw);
  }

  Future<void> saveRole(UserRole role) =>
      _storage.write(key: _roleKey, value: role.toJson);

  // ── Practitioner ────────────────────────────────────────────────────────────

  Future<void> saveActivationCode(String code) =>
      _storage.write(key: _activationKey, value: code);

  // ── Patient ─────────────────────────────────────────────────────────────────

  Future<void> savePatientEmail(String email) =>
      _storage.write(key: _emailKey, value: email);

  Future<String?> getPatientEmail() => _storage.read(key: _emailKey);

  // ── Clear ───────────────────────────────────────────────────────────────────

  Future<void> clearAll() => _storage.deleteAll();
}
