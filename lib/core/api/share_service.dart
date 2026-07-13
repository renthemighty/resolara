import 'package:dio/dio.dart';
import '../api/api_client.dart';
import '../crypto/share_crypto.dart';
import '../models/patient_result.dart';
import '../models/share_bundle.dart';

class ShareServiceException implements Exception {
  final String message;
  const ShareServiceException(this.message);
  @override String toString() => message;
}

class ShareService {
  final _dio = ApiClient.instance.dio;

  static const _maxCodeAttempts = 5;

  /// Practitioner: encrypt [bundle] client-side (AES-256-GCM, key never sent
  /// to the server — see `ShareCrypto`) and create a share record.
  ///
  /// The share code is generated here, not by the server, because it is
  /// used as AEAD associated data when encrypting — the server only
  /// validates format/uniqueness of the code the client already committed
  /// to in the ciphertext. On the (extremely unlikely) event of a code
  /// collision the server returns 409 and this retries with a fresh code.
  ///
  /// Returns the share code (safe to display/type) and the URL-safe key
  /// (NEVER send this to any server — combine as
  /// `https://resolara.ai/results/{code}#k={key}` for the QR/link only).
  Future<({String code, String key})> createShare({
    required String imageUrl,
    required Map<String, dynamic> bundle,
  }) async {
    DioException? lastError;
    for (var attempt = 0; attempt < _maxCodeAttempts; attempt++) {
      final code = ShareCrypto.generateCode();
      final encrypted = await ShareCrypto.encryptBundle(bundle: bundle, code: code);
      try {
        final res = await _dio.post('/v1/share', data: {
          'code':             code,
          'image_url':        imageUrl,
          'encrypted_bundle': encrypted.wire,
          'schema_version':   1,
        });
        final returnedCode = res.data['code'] as String? ?? code;
        return (code: returnedCode, key: encrypted.key);
      } on DioException catch (e) {
        if (e.response?.statusCode == 409) {
          lastError = e;
          continue; // code collision — regenerate and retry
        }
        final msg = e.response?.data?['error'] ?? e.message ?? 'Share failed.';
        throw ShareServiceException(msg.toString());
      }
    }
    final msg = lastError?.response?.data?['error'] ?? 'Could not generate a unique share code.';
    throw ShareServiceException(msg.toString());
  }

  /// Patient (no auth): fetch the raw share record (opaque ciphertext + image URL).
  Future<PatientResult> fetchResults(String code) async {
    final clean = code.replaceAll(RegExp(r'[^A-Za-z0-9]'), '').toUpperCase();
    try {
      final res = await ApiClient.instance.dioNoAuth
          .get('/v1/patient/results/$clean');
      return PatientResult.fromJson(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        throw const ShareServiceException(
            'Code not found or expired. Check the code and try again.');
      }
      if (e.response?.statusCode == 429) {
        throw const ShareServiceException(
            'Too many attempts. Please wait a bit and try again.');
      }
      final msg = e.response?.data?['error'] ?? e.message ?? 'Could not load results.';
      throw ShareServiceException(msg.toString());
    }
  }

  /// Decrypts [result]'s bundle using the key carried in the share link's
  /// URL fragment. Returns null (never throws) when [urlKey] is missing or
  /// decryption fails for any reason — callers should treat null as the
  /// "no personalization available" degraded view, not an error state.
  Future<ShareBundle?> decryptBundle(PatientResult result, String? urlKey) async {
    if (urlKey == null || urlKey.isEmpty || result.encryptedBundle.isEmpty) {
      return null;
    }
    try {
      final json = await ShareCrypto.decryptBundle(
        wire:   result.encryptedBundle,
        urlKey: urlKey,
        code:   result.code,
      );
      return ShareBundle.fromJson(json);
    } catch (_) {
      return null;
    }
  }
}
