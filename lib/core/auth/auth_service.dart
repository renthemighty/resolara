import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class AuthService {
  static const _storage = FlutterSecureStorage();
  static const _tokenKey = 'resolara_device_token';
  static const _activationKey = 'resolara_activation_code';

  Future<String?> getToken() async {
    return _storage.read(key: _tokenKey);
  }

  Future<void> saveToken(String token) async {
    await _storage.write(key: _tokenKey, value: token);
  }

  Future<void> clearToken() async {
    await _storage.delete(key: _tokenKey);
  }

  Future<bool> isActivated() async {
    final code = await _storage.read(key: _activationKey);
    return code != null && code.isNotEmpty;
  }

  Future<void> saveActivationCode(String code) async {
    await _storage.write(key: _activationKey, value: code);
  }

  Future<void> clearAll() async {
    await _storage.deleteAll();
  }
}
