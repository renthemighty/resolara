import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Stores per-share decryption keys locally so "My Results" keeps working
/// across app restarts. Keys never touch the server (see `ShareCrypto`) —
/// this is purely on-device persistence, mirroring `SecureFileStorage`'s use
/// of `flutter_secure_storage` elsewhere in the app.
class PatientShareKeyStorage {
  static const _storage = FlutterSecureStorage();

  static String _storageKey(String code) => 'resolara_share_key_${code.toUpperCase()}';

  static Future<void> save(String code, String urlKey) =>
      _storage.write(key: _storageKey(code), value: urlKey);

  /// Returns null if no key was ever saved for this code (e.g. the result
  /// was originally opened via a manually-typed code with no fragment key).
  static Future<String?> read(String code) => _storage.read(key: _storageKey(code));

  static Future<void> delete(String code) => _storage.delete(key: _storageKey(code));
}
