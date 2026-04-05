<?php
declare(strict_types=1);

require_once __DIR__ . '/services/SessionService.php';
require_once __DIR__ . '/services/CryptoService.php';

/**
 * ClinicContext — per-request session + clinic state.
 *
 * Call ClinicContext::require() at the top of any protected handler.
 * Handles:
 *   - Session lookup from cookie
 *   - 401 bounce if no session or expired
 *   - CSRF check on POST/PUT/DELETE
 *   - Clinic DEK unwrap (cached for request)
 *   - User row + clinic row load
 *
 * Fields available after require():
 *   $ctx->userId, $ctx->clinicId, $ctx->user, $ctx->clinic, $ctx->dek
 */
class ClinicContext
{
    public string $userId;
    public string $clinicId;
    public array $user;
    public array $clinic;
    public string $dek;
    public array $session;

    public static function require(PDO $pdo, bool $allowPendingMfa = false): self
    {
        $session = SessionService::validate($pdo, $allowPendingMfa);
        if (!$session) {
            Response::unauthorized();
        }

        $method = $_SERVER['REQUEST_METHOD'] ?? 'GET';
        if (in_array($method, ['POST', 'PUT', 'DELETE', 'PATCH'], true)) {
            if (!SessionService::verifyCsrf($session)) {
                Response::error('CSRF token missing or invalid', 403);
            }
        }

        $ctx = new self();
        $ctx->session = $session;
        $ctx->userId = $session['user_id'];
        $ctx->clinicId = $session['clinic_id'];

        $stmt = $pdo->prepare("
            SELECT id, clinic_id, email, role, totp_enabled, status
              FROM clinic_users
             WHERE id = ? AND status = 'active'
             LIMIT 1
        ");
        $stmt->execute([$ctx->userId]);
        $ctx->user = $stmt->fetch() ?: Response::unauthorized();

        $stmt = $pdo->prepare("
            SELECT id, tier, encrypted_dek, dek_key_id, status, max_practitioners,
                   max_patients, max_storage_gb
              FROM clinics
             WHERE id = ? AND status = 'active'
             LIMIT 1
        ");
        $stmt->execute([$ctx->clinicId]);
        $ctx->clinic = $stmt->fetch() ?: Response::error('Clinic inactive', 403);
        $ctx->dek = CryptoService::unwrapClinicDek(
            $ctx->clinicId,
            $ctx->clinic['encrypted_dek'],
            $ctx->clinic['dek_key_id']
        );

        return $ctx;
    }
}
