<?php
declare(strict_types=1);

require_once __DIR__ . '/CryptoService.php';

/**
 * SessionService — cookie-backed sessions for the clinic web app.
 *
 * Two cookies, both scoped to .resolara.ai so they traverse subdomains:
 *   resolara_session : httpOnly, Secure, SameSite=Lax — opaque token, the
 *                       SHA-256 hash of which is the PK in clinic_sessions
 *   resolara_csrf    : JS-readable, Secure, SameSite=Lax — sent by the web
 *                       app in X-CSRF-Token header on every mutating request
 *
 * Session lifetime:
 *   - Absolute: 7 days (expires_at written once on create)
 *   - Idle:     20 minutes (last_active_at refreshed on every hit, server
 *                enforces idle timeout on each validate())
 *
 * Pending-MFA sessions: when MFA is required but not yet verified, the
 * session is created with pending_mfa=1. The only endpoint that will
 * accept a pending_mfa session is /v1/clinic/auth/mfa-verify.
 */
class SessionService
{
    private const COOKIE_SESSION = 'resolara_session';
    private const COOKIE_CSRF = 'resolara_csrf';
    private const COOKIE_DOMAIN = '.resolara.ai';
    private const ABSOLUTE_TTL = 604800;   // 7 days in seconds
    private const IDLE_TTL = 1200;         // 20 minutes in seconds

    /**
     * Create a new session row, emit both cookies, return the session row
     * for the caller to act on.
     *
     * @return array{token: string, csrf: string, expires_at: string}
     */
    public static function create(PDO $pdo, string $userId, string $clinicId, bool $pendingMfa = false): array
    {
        $token = CryptoService::randomToken(32);
        $csrf = CryptoService::randomToken(24);
        $tokenHash = CryptoService::hashToken($token);

        $ip = self::clientIpBinary();
        $uaHash = self::userAgentHash();
        $expiresAt = date('Y-m-d H:i:s', time() + self::ABSOLUTE_TTL);

        $stmt = $pdo->prepare("
            INSERT INTO clinic_sessions
                (token_hash, user_id, clinic_id, csrf_token, ip_address,
                 user_agent_hash, expires_at, pending_mfa)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?)
        ");
        $stmt->execute([
            $tokenHash, $userId, $clinicId, $csrf, $ip, $uaHash, $expiresAt,
            $pendingMfa ? 1 : 0,
        ]);

        self::emitCookies($token, $csrf);

        return ['token' => $token, 'csrf' => $csrf, 'expires_at' => $expiresAt];
    }

    /**
     * Clear the MFA-pending flag on a session once TOTP is verified.
     */
    public static function promoteAfterMfa(PDO $pdo, string $tokenHash): void
    {
        $stmt = $pdo->prepare("
            UPDATE clinic_sessions
               SET pending_mfa = 0,
                   last_active_at = CURRENT_TIMESTAMP
             WHERE token_hash = ?
        ");
        $stmt->execute([$tokenHash]);
    }

    /**
     * Look up the current session from the resolara_session cookie, enforce
     * idle + absolute timeouts, return the session row or null.
     *
     * @return array<string,mixed>|null
     */
    public static function validate(PDO $pdo, bool $allowPendingMfa = false): ?array
    {
        $cookie = $_COOKIE[self::COOKIE_SESSION] ?? '';
        if ($cookie === '') return null;

        $tokenHash = CryptoService::hashToken($cookie);
        $stmt = $pdo->prepare("
            SELECT token_hash, user_id, clinic_id, csrf_token, pending_mfa,
                   expires_at, last_active_at
              FROM clinic_sessions
             WHERE token_hash = ?
             LIMIT 1
        ");
        $stmt->execute([$tokenHash]);
        $row = $stmt->fetch();
        if (!$row) return null;

        // Absolute timeout
        if (strtotime($row['expires_at']) < time()) {
            self::destroy($pdo, $tokenHash);
            return null;
        }

        // Idle timeout
        $idleSeconds = time() - strtotime($row['last_active_at']);
        if ($idleSeconds > self::IDLE_TTL) {
            self::destroy($pdo, $tokenHash);
            return null;
        }

        // MFA gate
        if ((int)$row['pending_mfa'] === 1 && !$allowPendingMfa) {
            return null;
        }

        // Refresh activity timestamp
        $pdo->prepare("UPDATE clinic_sessions SET last_active_at = CURRENT_TIMESTAMP WHERE token_hash = ?")
            ->execute([$tokenHash]);

        return $row;
    }

    /**
     * Verify the X-CSRF-Token header matches the session's stored CSRF
     * token. Call on every mutating (POST/PUT/DELETE) request.
     */
    public static function verifyCsrf(array $session): bool
    {
        $header = $_SERVER['HTTP_X_CSRF_TOKEN'] ?? '';
        if ($header === '') return false;
        return hash_equals($session['csrf_token'], $header);
    }

    /**
     * Destroy the session row and clear both cookies.
     */
    public static function destroy(PDO $pdo, string $tokenHash): void
    {
        $pdo->prepare("DELETE FROM clinic_sessions WHERE token_hash = ?")->execute([$tokenHash]);
        self::clearCookies();
    }

    /**
     * Destroy whichever session the current request is carrying (used by
     * /v1/clinic/auth/logout).
     */
    public static function logout(PDO $pdo): void
    {
        $cookie = $_COOKIE[self::COOKIE_SESSION] ?? '';
        if ($cookie !== '') {
            self::destroy($pdo, CryptoService::hashToken($cookie));
        } else {
            self::clearCookies();
        }
    }

    // ── Cookie emission ────────────────────────────────────────────────────

    private static function emitCookies(string $token, string $csrf): void
    {
        $opts = [
            'expires'  => time() + self::ABSOLUTE_TTL,
            'path'     => '/',
            'domain'   => self::COOKIE_DOMAIN,
            'secure'   => true,
            'httponly' => true,
            'samesite' => 'Lax',
        ];
        setcookie(self::COOKIE_SESSION, $token, $opts);

        $csrfOpts = $opts;
        $csrfOpts['httponly'] = false; // JS needs to read this to set X-CSRF-Token
        setcookie(self::COOKIE_CSRF, $csrf, $csrfOpts);
    }

    private static function clearCookies(): void
    {
        $opts = [
            'expires'  => time() - 3600,
            'path'     => '/',
            'domain'   => self::COOKIE_DOMAIN,
            'secure'   => true,
            'samesite' => 'Lax',
        ];
        setcookie(self::COOKIE_SESSION, '', $opts + ['httponly' => true]);
        setcookie(self::COOKIE_CSRF, '', $opts + ['httponly' => false]);
    }

    // ── Request context helpers ────────────────────────────────────────────

    private static function clientIpBinary(): ?string
    {
        $ip = $_SERVER['HTTP_X_FORWARDED_FOR'] ?? $_SERVER['REMOTE_ADDR'] ?? '';
        if ($ip === '') return null;
        if (str_contains($ip, ',')) $ip = trim(explode(',', $ip)[0]);
        $packed = @inet_pton($ip);
        return $packed === false ? null : $packed;
    }

    private static function userAgentHash(): ?string
    {
        $ua = $_SERVER['HTTP_USER_AGENT'] ?? '';
        return $ua === '' ? null : hash('sha256', $ua);
    }
}
