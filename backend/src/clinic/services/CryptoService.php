<?php
declare(strict_types=1);

/**
 * CryptoService — envelope encryption for clinic PHI.
 *
 * Architecture:
 *   Master Key  (env var RESOLARA_MASTER_KEY_v1, 32 bytes base64, rotated yearly)
 *      |
 *      +--> Per-Clinic DEK (32 random bytes, wrapped with master key via
 *           sodium_crypto_secretbox, stored in clinics.encrypted_dek as
 *           nonce(24) || ciphertext || mac)
 *           |
 *           +--> Per-record field encrypted with AES-256-GCM:
 *                output = nonce(12) || ciphertext || tag(16)
 *
 * Key rotation: when RESOLARA_MASTER_KEY_v2 is introduced, old DEKs can be
 * unwrapped with v1 and rewrapped with v2. dek_key_id on the clinics row
 * tracks which master key wrapped each DEK.
 *
 * libsodium is required (PHP 7.2+ has it built in). AES-256-GCM via
 * sodium_crypto_aead_aes256gcm_* — only available on CPUs with AES-NI,
 * which OVH's Xeon servers have.
 */
class CryptoService
{
    private const DEK_LENGTH = 32;
    private const NONCE_LENGTH_GCM = 12;

    /** @var array<string,string> cached per-clinic DEKs (unwrapped) */
    private static array $dekCache = [];

    /**
     * Generate a fresh per-clinic DEK, wrap it with the current master key,
     * and return both halves.
     *
     * @return array{encrypted_dek: string, key_id: string, dek: string}
     */
    public static function generateClinicDek(): array
    {
        $keyId = self::currentMasterKeyId();
        $masterKey = self::masterKey($keyId);

        $dek = random_bytes(self::DEK_LENGTH);
        $nonce = random_bytes(SODIUM_CRYPTO_SECRETBOX_NONCEBYTES);
        $wrapped = sodium_crypto_secretbox($dek, $nonce, $masterKey);

        return [
            'encrypted_dek' => $nonce . $wrapped,
            'key_id' => $keyId,
            'dek' => $dek,
        ];
    }

    /**
     * Unwrap a stored per-clinic DEK. Cached by clinic_id for the request.
     */
    public static function unwrapClinicDek(string $clinicId, string $encryptedDek, string $keyId): string
    {
        if (isset(self::$dekCache[$clinicId])) {
            return self::$dekCache[$clinicId];
        }

        $masterKey = self::masterKey($keyId);
        $nonce = substr($encryptedDek, 0, SODIUM_CRYPTO_SECRETBOX_NONCEBYTES);
        $cipher = substr($encryptedDek, SODIUM_CRYPTO_SECRETBOX_NONCEBYTES);

        $dek = sodium_crypto_secretbox_open($cipher, $nonce, $masterKey);
        if ($dek === false) {
            throw new RuntimeException('Failed to unwrap clinic DEK — wrong master key?');
        }

        self::$dekCache[$clinicId] = $dek;
        return $dek;
    }

    /**
     * Encrypt a PHI field with a per-clinic DEK.
     * Returns binary string: nonce(12) || ciphertext || tag(16).
     */
    public static function encrypt(string $plaintext, string $dek): string
    {
        if (!sodium_crypto_aead_aes256gcm_is_available()) {
            throw new RuntimeException('AES-256-GCM unavailable (CPU needs AES-NI)');
        }
        $nonce = random_bytes(self::NONCE_LENGTH_GCM);
        $cipher = sodium_crypto_aead_aes256gcm_encrypt($plaintext, '', $nonce, $dek);
        return $nonce . $cipher;
    }

    /**
     * Decrypt a PHI field with the per-clinic DEK. Returns null on failure
     * (tampered ciphertext, wrong DEK, etc.) so callers can distinguish.
     */
    public static function decrypt(string $encrypted, string $dek): ?string
    {
        if (strlen($encrypted) < self::NONCE_LENGTH_GCM + 16) {
            return null;
        }
        $nonce = substr($encrypted, 0, self::NONCE_LENGTH_GCM);
        $cipher = substr($encrypted, self::NONCE_LENGTH_GCM);
        try {
            $plain = sodium_crypto_aead_aes256gcm_decrypt($cipher, '', $nonce, $dek);
            return $plain === false ? null : $plain;
        } catch (SodiumException) {
            return null;
        }
    }

    /**
     * Argon2id password hashing with defaults tuned for a web server.
     */
    public static function hashPassword(string $password): string
    {
        return password_hash($password, PASSWORD_ARGON2ID, [
            'memory_cost' => 64 * 1024,
            'time_cost'   => 3,
            'threads'     => 2,
        ]);
    }

    public static function verifyPassword(string $password, string $hash): bool
    {
        return password_verify($password, $hash);
    }

    /**
     * Generate a cryptographically random token for session IDs, CSRF tokens,
     * etc. Output is base64url (no padding, URL-safe).
     */
    public static function randomToken(int $bytes = 32): string
    {
        return rtrim(strtr(base64_encode(random_bytes($bytes)), '+/', '-_'), '=');
    }

    /**
     * Hash a session token for DB storage — we never store raw tokens, only
     * the SHA-256 digest. Lookups rebuild the digest from the cookie value.
     */
    public static function hashToken(string $token): string
    {
        return hash('sha256', $token);
    }

    // ── Master key resolution ───────────────────────────────────────────────

    /**
     * Returns the active master key ID. Defaults to "v1" — rotate by
     * incrementing when a new key is provisioned.
     */
    public static function currentMasterKeyId(): string
    {
        return defined('RESOLARA_CURRENT_MASTER_KEY_ID')
            ? RESOLARA_CURRENT_MASTER_KEY_ID
            : 'v1';
    }

    /**
     * Fetch a master key by ID. Keys live in environment variables named
     * RESOLARA_MASTER_KEY_<id> (e.g. RESOLARA_MASTER_KEY_v1). Encoded as
     * base64, must decode to exactly 32 bytes.
     */
    private static function masterKey(string $keyId): string
    {
        $envName = 'RESOLARA_MASTER_KEY_' . $keyId;
        $b64 = getenv($envName);
        if ($b64 === false || $b64 === '') {
            // Fall back to PHP constant (defined in config.php for local dev)
            if (defined($envName)) {
                $b64 = constant($envName);
            } else {
                throw new RuntimeException("Master key $envName not configured");
            }
        }
        $key = base64_decode($b64, true);
        if ($key === false || strlen($key) !== self::DEK_LENGTH) {
            throw new RuntimeException("Master key $envName must be base64-encoded 32 bytes");
        }
        return $key;
    }
}
