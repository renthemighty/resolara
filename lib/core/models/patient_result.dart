/// Raw, server-visible share record. `encryptedBundle` is opaque ciphertext
/// the server cannot read — decrypt it with `ShareCrypto.decryptBundle()`
/// using the key from the share link's URL fragment (see `ShareBundle`).
class PatientResult {
  final String code;
  final String imageUrl;
  final String encryptedBundle;
  final String? expiresAt;

  const PatientResult({
    required this.code,
    required this.imageUrl,
    required this.encryptedBundle,
    this.expiresAt,
  });

  factory PatientResult.fromJson(Map<String, dynamic> json) => PatientResult(
        code:            json['code']             as String? ?? '',
        imageUrl:        json['image_url']        as String? ?? '',
        encryptedBundle: json['encrypted_bundle'] as String? ?? '',
        expiresAt:       json['expires_at']        as String?,
      );
}
