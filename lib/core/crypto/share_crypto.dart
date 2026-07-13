import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

class ShareCryptoException implements Exception {
  final String message;
  const ShareCryptoException(this.message);
  @override
  String toString() => message;
}

/// Zero-knowledge encryption for patient share bundles.
///
/// The server that stores a share is never given the decryption key — it
/// only ever sees the wire-format ciphertext produced by [encryptBundle].
/// The key lives solely in the URL fragment (`#k=...`) of the share link,
/// which browsers and HTTP clients never transmit to a server.
///
/// Primitive: AES-256-GCM (`package:cryptography`'s `AesGcm.with256bits()`).
///   - Key: 32 random bytes from a CSPRNG, generated fresh per share.
///   - Nonce: 12 random bytes, generated fresh per encryption.
///   - AAD: the ASCII bytes of the 6-char share code — binds the ciphertext
///     to its code so a malicious/compromised server can't swap ciphertext
///     between two codes.
///   - Wire format: base64( nonce(12) || ciphertext || tag(16) ).
class ShareCrypto {
  static final AesGcm _algorithm = AesGcm.with256bits();

  /// Charset matches the server's share-code alphabet (ambiguous chars
  /// I/O/0/1 excluded) — the client generates the code because it must be
  /// known before encryption (it's used as AAD).
  static const _codeChars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';

  /// Generates a fresh random 6-character share code.
  static String generateCode() {
    final rnd = Random.secure();
    return List.generate(
        6, (_) => _codeChars[rnd.nextInt(_codeChars.length)]).join();
  }

  /// Encodes raw key bytes as URL-safe base64 with no padding, so it can be
  /// dropped straight into a URL fragment.
  static String encodeKeyForUrl(List<int> keyBytes) =>
      base64Url.encode(keyBytes).replaceAll('=', '');

  /// Decodes a URL-fragment key string back to raw bytes.
  static List<int> decodeKeyFromUrl(String urlKey) {
    var padded = urlKey;
    while (padded.length % 4 != 0) {
      padded += '=';
    }
    return base64Url.decode(padded);
  }

  /// Encrypts [bundle] (a JSON-encodable map) for share [code].
  /// Returns the wire-format ciphertext and the URL-safe key — the caller
  /// must send [wire] to the server and keep [key] client-side only
  /// (embedded in the QR/link fragment, never in a request body/header/query).
  static Future<({String wire, String key})> encryptBundle({
    required Map<String, dynamic> bundle,
    required String code,
  }) async {
    final secretKey = await _algorithm.newSecretKey();
    final keyBytes = await secretKey.extractBytes();
    final plaintext = utf8.encode(jsonEncode(bundle));
    final nonce = _algorithm.newNonce();

    final secretBox = await _algorithm.encrypt(
      plaintext,
      secretKey: secretKey,
      nonce: nonce,
      aad: utf8.encode(code),
    );

    final wireBytes = Uint8List(
        secretBox.nonce.length + secretBox.cipherText.length + secretBox.mac.bytes.length);
    var offset = 0;
    wireBytes.setAll(offset, secretBox.nonce);
    offset += secretBox.nonce.length;
    wireBytes.setAll(offset, secretBox.cipherText);
    offset += secretBox.cipherText.length;
    wireBytes.setAll(offset, secretBox.mac.bytes);

    return (wire: base64.encode(wireBytes), key: encodeKeyForUrl(keyBytes));
  }

  /// Decrypts a wire-format ciphertext using the URL-fragment key and the
  /// share code (as AAD). Throws [ShareCryptoException] on any failure —
  /// callers on the patient path should catch this and degrade gracefully
  /// (render the image with no personalization) rather than crash.
  static Future<Map<String, dynamic>> decryptBundle({
    required String wire,
    required String urlKey,
    required String code,
  }) async {
    const nonceLen = 12;
    const tagLen = 16;
    try {
      final raw = base64.decode(wire);
      if (raw.length < nonceLen + tagLen) {
        throw const ShareCryptoException('Malformed encrypted bundle.');
      }
      final nonce = raw.sublist(0, nonceLen);
      final tag = raw.sublist(raw.length - tagLen);
      final cipherText = raw.sublist(nonceLen, raw.length - tagLen);

      final keyBytes = decodeKeyFromUrl(urlKey);
      final secretKey = SecretKey(keyBytes);
      final secretBox = SecretBox(cipherText, nonce: nonce, mac: Mac(tag));

      final clear = await _algorithm.decrypt(
        secretBox,
        secretKey: secretKey,
        aad: utf8.encode(code),
      );

      final decoded = jsonDecode(utf8.decode(clear));
      if (decoded is! Map<String, dynamic>) {
        throw const ShareCryptoException('Malformed decrypted bundle.');
      }
      return decoded;
    } on ShareCryptoException {
      rethrow;
    } catch (_) {
      throw const ShareCryptoException(
          'Could not decrypt results. The link or code may be invalid.');
    }
  }
}
