import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:encrypt/encrypt.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// AES-256 CTR encryption for approved visualization files.
/// Key is generated once and stored in flutter_secure_storage.
/// Encrypted file layout: [16-byte IV][ciphertext]
class SecureFileStorage {
  static const _keyName = 'resolara_file_key';
  static const _storage = FlutterSecureStorage();

  static Future<Key> _getOrCreateKey() async {
    var keyStr = await _storage.read(key: _keyName);
    if (keyStr == null) {
      final rng = Random.secure();
      final bytes = List<int>.generate(32, (_) => rng.nextInt(256));
      keyStr = base64.encode(bytes);
      await _storage.write(key: _keyName, value: keyStr);
    }
    return Key.fromBase64(keyStr);
  }

  /// Encrypt [plainBytes] and write to [dest].
  static Future<void> writeEncrypted(File dest, Uint8List plainBytes) async {
    final key = await _getOrCreateKey();
    final iv = IV.fromSecureRandom(16);
    final encrypter = Encrypter(AES(key, mode: AESMode.ctr));
    final encrypted = encrypter.encryptBytes(plainBytes, iv: iv);

    final out = Uint8List(16 + encrypted.bytes.length);
    out.setAll(0, iv.bytes);
    out.setAll(16, encrypted.bytes);
    await dest.writeAsBytes(out, flush: true);
  }

  /// Read and decrypt a file written by [writeEncrypted].
  /// Falls back to returning raw bytes for legacy unencrypted files.
  static Future<Uint8List?> readDecrypted(File file) async {
    if (!file.existsSync()) return null;
    try {
      final fileBytes = await file.readAsBytes();
      if (fileBytes.length < 17) return fileBytes;

      // Detect legacy unencrypted image (JPEG = FF D8, PNG = 89 50)
      final isRawImage =
          (fileBytes[0] == 0xFF && fileBytes[1] == 0xD8) ||
          (fileBytes[0] == 0x89 && fileBytes[1] == 0x50);
      if (isRawImage) return fileBytes;

      final key = await _getOrCreateKey();
      final iv = IV(Uint8List.fromList(fileBytes.sublist(0, 16)));
      final cipher = Uint8List.fromList(fileBytes.sublist(16));
      final encrypter = Encrypter(AES(key, mode: AESMode.ctr));
      return Uint8List.fromList(encrypter.decryptBytes(Encrypted(cipher), iv: iv));
    } catch (_) {
      // Last resort — return raw bytes (handles any unencrypted legacy file)
      try {
        return await file.readAsBytes();
      } catch (_) {
        return null;
      }
    }
  }
}
