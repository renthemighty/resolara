<?php
declare(strict_types=1);

require_once __DIR__ . '/../services/CryptoService.php';
require_once __DIR__ . '/../services/SessionService.php';
require_once __DIR__ . '/../services/LoginThrottleService.php';
require_once __DIR__ . '/../services/TotpService.php';
require_once __DIR__ . '/../services/AuditService.php';
require_once __DIR__ . '/../ClinicContext.php';

/**
 * Handles clinic auth endpoints used by app.resolara.ai:
 *   POST /v1/clinic/auth/login         - email + password
 *   POST /v1/clinic/auth/mfa-verify    - TOTP (requires pending_mfa session)
 *   POST /v1/clinic/auth/logout
 *   GET  /v1/clinic/auth/me
 *
 * Login flow:
 *   1. Client POSTs {email, password}
 *   2. Throttle check (per-email + per-IP)
 *   3. Verify password (Argon2id via password_verify)
 *   4. If user has totp_enabled → create pending_mfa session, return
 *      {status:"mfa_required"} — client swaps to 6-digit field
 *   5. Else → create full session, return {status:"ok", user:{...}}
 *
 * MFA verify flow:
 *   1. Client POSTs {code} with pending_mfa session cookie
 *   2. Unwrap TOTP secret with clinic DEK, verify via TotpService
 *   3. On success → promoteAfterMfa(), return {status:"ok"}
 *   4. On failure → record fail, keep pending_mfa session for retry
 */
class ClinicAuthHandler
{
    public static function login(): void
    {
        if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
            Response::error('Method not allowed', 405);
        }

        $body = json_decode(file_get_contents('php://input') ?: '', true);
        $email = trim((string)($body['email'] ?? ''));
        $password = (string)($body['password'] ?? '');
        if ($email === '' || $password === '') {
            Response::error('email and password required');
        }
        $emailLower = strtolower($email);

        $pdo = Database::get();

        // Throttle
        $throttle = LoginThrottleService::check($pdo, $emailLower);
        if (!$throttle['ok']) {
            header('Retry-After: ' . $throttle['retry_after']);
            Response::json([
                'status' => 'throttled',
                'reason' => $throttle['reason'],
                'retry_after' => $throttle['retry_after'],
            ], 429);
        }

        // Look up user
        $stmt = $pdo->prepare("
            SELECT id, clinic_id, email, password_hash, totp_secret_encrypted,
                   totp_enabled, role, status
              FROM clinic_users
             WHERE email_lower = ?
             LIMIT 1
        ");
        $stmt->execute([$emailLower]);
        $user = $stmt->fetch();

        if (!$user
            || $user['status'] !== 'active'
            || !CryptoService::verifyPassword($password, $user['password_hash'])) {
            LoginThrottleService::record($pdo, $emailLower, false);
            AuditService::log(
                $pdo, 'login_failed', 'failed_auth',
                null, null, 'user', $user['id'] ?? null, false,
                ['email_lower' => $emailLower]
            );
            Response::error('Invalid email or password', 401);
        }

        LoginThrottleService::record($pdo, $emailLower, true);

        // Verify clinic is active
        $stmt = $pdo->prepare("SELECT status FROM clinics WHERE id = ?");
        $stmt->execute([$user['clinic_id']]);
        $clinic = $stmt->fetch();
        if (!$clinic || $clinic['status'] !== 'active') {
            Response::error('Clinic inactive', 403);
        }

        $pendingMfa = (int)$user['totp_enabled'] === 1;
        $session = SessionService::create($pdo, $user['id'], $user['clinic_id'], $pendingMfa);

        // Update last_login_at only on full success (not pending MFA)
        if (!$pendingMfa) {
            $pdo->prepare("UPDATE clinic_users SET last_login_at = NOW() WHERE id = ?")
                ->execute([$user['id']]);
        }

        AuditService::log(
            $pdo, 'login', $pendingMfa ? 'failed_auth' : 'login',
            $user['clinic_id'], $user['id'], 'user', $user['id'],
            true, ['pending_mfa' => $pendingMfa]
        );

        if ($pendingMfa) {
            Response::json(['status' => 'mfa_required', 'token' => $session['token']]);
        }
        Response::json([
            'status' => 'ok',
            'token' => $session['token'],
            'user' => [
                'id' => $user['id'],
                'email' => $user['email'],
                'role' => $user['role'],
                'clinic_id' => $user['clinic_id'],
            ],
        ]);
    }

    public static function mfaVerify(): void
    {
        if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
            Response::error('Method not allowed', 405);
        }

        $body = json_decode(file_get_contents('php://input') ?: '', true);
        $code = trim((string)($body['code'] ?? ''));
        if ($code === '') Response::error('code required');

        $pdo = Database::get();

        $session = SessionService::validate($pdo, allowPendingMfa: true);
        if (!$session) Response::unauthorized();
        if ((int)$session['pending_mfa'] !== 1) {
            Response::error('MFA already verified for this session', 400);
        }

        // Load user + decrypt TOTP secret
        $stmt = $pdo->prepare("
            SELECT u.id, u.email, u.role, u.totp_secret_encrypted,
                   c.encrypted_dek, c.dek_key_id
              FROM clinic_users u
              JOIN clinics c ON c.id = u.clinic_id
             WHERE u.id = ?
        ");
        $stmt->execute([$session['user_id']]);
        $row = $stmt->fetch();
        if (!$row || !$row['totp_secret_encrypted']) {
            Response::error('MFA not configured', 400);
        }

        $dek = CryptoService::unwrapClinicDek(
            $session['clinic_id'], $row['encrypted_dek'], $row['dek_key_id']
        );
        $secret = CryptoService::decrypt($row['totp_secret_encrypted'], $dek);
        if ($secret === null) Response::error('MFA secret unreadable', 500);

        if (!TotpService::verify($secret, $code)) {
            AuditService::log(
                $pdo, 'mfa_failed', 'failed_auth',
                $session['clinic_id'], $session['user_id'], 'user', $session['user_id'], false
            );
            Response::error('Invalid code', 401);
        }

        SessionService::promoteAfterMfa($pdo, $session['token_hash']);
        $pdo->prepare("UPDATE clinic_users SET last_login_at = NOW() WHERE id = ?")
            ->execute([$session['user_id']]);

        AuditService::log(
            $pdo, 'login', 'login',
            $session['clinic_id'], $session['user_id'], 'user', $session['user_id'], true
        );

        Response::json([
            'status' => 'ok',
            'user' => [
                'id' => $row['id'],
                'email' => $row['email'],
                'role' => $row['role'],
                'clinic_id' => $session['clinic_id'],
            ],
        ]);
    }

    public static function logout(): void
    {
        if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
            Response::error('Method not allowed', 405);
        }
        $pdo = Database::get();
        $session = SessionService::validate($pdo, allowPendingMfa: true);
        if ($session) {
            AuditService::log(
                $pdo, 'logout', 'logout',
                $session['clinic_id'], $session['user_id'], 'user', $session['user_id'], true
            );
        }
        SessionService::logout($pdo);
        Response::json(['status' => 'ok']);
    }

    public static function me(): void
    {
        $pdo = Database::get();
        $ctx = ClinicContext::require($pdo);
        Response::json([
            'user' => [
                'id' => $ctx->user['id'],
                'email' => $ctx->user['email'],
                'role' => $ctx->user['role'],
                'totp_enabled' => (bool)$ctx->user['totp_enabled'],
            ],
            'clinic' => [
                'id' => $ctx->clinic['id'],
                'tier' => $ctx->clinic['tier'],
                'max_practitioners' => (int)$ctx->clinic['max_practitioners'],
                'max_patients' => (int)$ctx->clinic['max_patients'],
                'max_storage_gb' => (int)$ctx->clinic['max_storage_gb'],
            ],
        ]);
    }
}
