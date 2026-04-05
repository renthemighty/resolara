<?php
declare(strict_types=1);

/**
 * TotpService — RFC 6238 TOTP verifier for clinic MFA.
 *
 * Standard 6-digit, 30-second window, SHA-1 HMAC. Accepts codes from a
 * +/- 1 step window (±30s) to tolerate clock drift. Secrets are stored
 * envelope-encrypted in clinic_users.totp_secret_encrypted.
 *
 * Enrollment (to be wired in /v1/clinic/auth/mfa-setup):
 *   1. Generate 20 random bytes as secret
 *   2. Encode as base32 for the authenticator app
 *   3. Build otpauth:// URI, render QR
 *   4. User confirms with first code → we verify and flip totp_enabled = 1
 */
class TotpService
{
    private const DIGITS = 6;
    private const PERIOD = 30;

    /**
     * Verify a user-submitted 6-digit code against a secret.
     * Accepts ±1 step window for clock skew.
     */
    public static function verify(string $secret, string $code): bool
    {
        $code = preg_replace('/\D/', '', $code);
        if ($code === '' || strlen($code) !== self::DIGITS) return false;

        $now = (int) floor(time() / self::PERIOD);
        for ($offset = -1; $offset <= 1; $offset++) {
            if (hash_equals(self::generateCode($secret, $now + $offset), $code)) {
                return true;
            }
        }
        return false;
    }

    /**
     * Generate a fresh random secret (20 bytes = 160 bits, RFC 6238 default).
     */
    public static function generateSecret(): string
    {
        return random_bytes(20);
    }

    /**
     * Base32 encode a secret for display in authenticator apps.
     */
    public static function base32Encode(string $bytes): string
    {
        $alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ234567';
        $out = '';
        $n = 0;
        $bitsLeft = 0;
        for ($i = 0; $i < strlen($bytes); $i++) {
            $n = ($n << 8) | ord($bytes[$i]);
            $bitsLeft += 8;
            while ($bitsLeft >= 5) {
                $bitsLeft -= 5;
                $out .= $alphabet[($n >> $bitsLeft) & 0x1F];
            }
        }
        if ($bitsLeft > 0) {
            $out .= $alphabet[($n << (5 - $bitsLeft)) & 0x1F];
        }
        return $out;
    }

    /**
     * Build an otpauth:// URI for QR rendering.
     */
    public static function otpauthUri(string $secret, string $accountEmail, string $issuer = 'Resolara Clinic'): string
    {
        $label = rawurlencode($issuer) . ':' . rawurlencode($accountEmail);
        $params = http_build_query([
            'secret' => self::base32Encode($secret),
            'issuer' => $issuer,
            'algorithm' => 'SHA1',
            'digits' => self::DIGITS,
            'period' => self::PERIOD,
        ]);
        return "otpauth://totp/$label?$params";
    }

    // ── Internal ────────────────────────────────────────────────────────────

    private static function generateCode(string $secret, int $counter): string
    {
        // 8-byte big-endian counter
        $counterBin = pack('J', $counter);
        $hash = hash_hmac('sha1', $counterBin, $secret, true);
        $offset = ord($hash[strlen($hash) - 1]) & 0x0F;
        $binary =
            ((ord($hash[$offset    ]) & 0x7F) << 24) |
            ((ord($hash[$offset + 1]) & 0xFF) << 16) |
            ((ord($hash[$offset + 2]) & 0xFF) <<  8) |
             (ord($hash[$offset + 3]) & 0xFF);
        $code = $binary % (10 ** self::DIGITS);
        return str_pad((string)$code, self::DIGITS, '0', STR_PAD_LEFT);
    }
}
