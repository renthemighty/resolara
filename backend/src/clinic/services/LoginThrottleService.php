<?php
declare(strict_types=1);

/**
 * LoginThrottleService — failed-login lockouts.
 *
 * Per-email: 5 failures in 15 min → account locked for 30 min, email alert.
 * Per-IP:    20 failures in 1 hour → IP throttled.
 *
 * Attempts recorded in clinic_login_attempts. Old rows (>48h) can be pruned
 * by a cron job; the policy windows are short enough that the table stays
 * small in practice.
 */
class LoginThrottleService
{
    private const EMAIL_WINDOW_MINUTES = 15;
    private const EMAIL_MAX_FAILS = 5;
    private const IP_WINDOW_MINUTES = 60;
    private const IP_MAX_FAILS = 20;

    public static function record(PDO $pdo, string $emailLower, bool $success): void
    {
        $stmt = $pdo->prepare("
            INSERT INTO clinic_login_attempts (email_lower, ip_address, success)
            VALUES (?, ?, ?)
        ");
        $stmt->execute([$emailLower, self::clientIpBinary(), $success ? 1 : 0]);
    }

    /**
     * Check whether this email+IP combo is allowed to attempt a login.
     * Returns an array; caller rejects with 429 if $ok === false.
     *
     * @return array{ok: bool, reason?: string, retry_after?: int}
     */
    public static function check(PDO $pdo, string $emailLower): array
    {
        // Email rule
        $stmt = $pdo->prepare("
            SELECT COUNT(*) AS fails
              FROM clinic_login_attempts
             WHERE email_lower = ?
               AND success = 0
               AND created_at > (NOW() - INTERVAL ? MINUTE)
        ");
        $stmt->execute([$emailLower, self::EMAIL_WINDOW_MINUTES]);
        $emailFails = (int)($stmt->fetch()['fails'] ?? 0);
        if ($emailFails >= self::EMAIL_MAX_FAILS) {
            return [
                'ok' => false,
                'reason' => 'email_locked',
                'retry_after' => self::EMAIL_WINDOW_MINUTES * 60,
            ];
        }

        // IP rule
        $ip = self::clientIpBinary();
        if ($ip !== null) {
            $stmt = $pdo->prepare("
                SELECT COUNT(*) AS fails
                  FROM clinic_login_attempts
                 WHERE ip_address = ?
                   AND success = 0
                   AND created_at > (NOW() - INTERVAL ? MINUTE)
            ");
            $stmt->execute([$ip, self::IP_WINDOW_MINUTES]);
            $ipFails = (int)($stmt->fetch()['fails'] ?? 0);
            if ($ipFails >= self::IP_MAX_FAILS) {
                return [
                    'ok' => false,
                    'reason' => 'ip_throttled',
                    'retry_after' => self::IP_WINDOW_MINUTES * 60,
                ];
            }
        }

        return ['ok' => true];
    }

    private static function clientIpBinary(): ?string
    {
        $ip = $_SERVER['HTTP_X_FORWARDED_FOR'] ?? $_SERVER['REMOTE_ADDR'] ?? '';
        if ($ip === '') return null;
        if (str_contains($ip, ',')) $ip = trim(explode(',', $ip)[0]);
        $packed = @inet_pton($ip);
        return $packed === false ? null : $packed;
    }
}
