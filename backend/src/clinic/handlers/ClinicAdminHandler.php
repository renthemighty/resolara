<?php
declare(strict_types=1);

require_once __DIR__ . '/../ClinicContext.php';
require_once __DIR__ . '/../services/CryptoService.php';
require_once __DIR__ . '/../services/AuditService.php';

/**
 * ClinicAdminHandler — practitioner management for clinic admins.
 *
 * Only users with role='admin' can access these endpoints.
 *
 * GET    /v1/clinic/admin/practitioners           — list all practitioners
 * POST   /v1/clinic/admin/practitioners           — invite/create a practitioner
 * PUT    /v1/clinic/admin/practitioners/<id>       — update role or status
 * DELETE /v1/clinic/admin/practitioners/<id>       — deactivate (soft)
 */
class ClinicAdminHandler
{
    private static function requireAdmin(PDO $pdo): ClinicContext
    {
        $ctx = ClinicContext::require($pdo);
        if ($ctx->user['role'] !== 'admin') {
            Response::error('Admin access required', 403);
        }
        return $ctx;
    }

    /**
     * GET /v1/clinic/admin/practitioners
     * Returns all practitioners (active + disabled) for this clinic.
     */
    public static function listPractitioners(): void
    {
        $pdo = Database::get();
        $ctx = self::requireAdmin($pdo);

        $stmt = $pdo->prepare("
            SELECT id, email, role, status, totp_enabled, last_login_at, created_at
              FROM clinic_users
             WHERE clinic_id = ?
             ORDER BY created_at ASC
        ");
        $stmt->execute([$ctx->clinicId]);
        $rows = $stmt->fetchAll();

        $practitioners = [];
        foreach ($rows as $row) {
            $practitioners[] = [
                'id' => $row['id'],
                'email' => $row['email'],
                'role' => $row['role'],
                'status' => $row['status'],
                'totp_enabled' => (bool)$row['totp_enabled'],
                'last_login_at' => $row['last_login_at'],
                'created_at' => $row['created_at'],
            ];
        }

        Response::json([
            'practitioners' => $practitioners,
            'total' => count($practitioners),
            'max_practitioners' => (int)$ctx->clinic['max_practitioners'],
        ]);
    }

    /**
     * POST /v1/clinic/admin/practitioners
     * Creates a new practitioner account.
     * Body: {email, password, role?}
     */
    public static function create(): void
    {
        if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
            Response::error('Method not allowed', 405);
        }

        $pdo = Database::get();
        $ctx = self::requireAdmin($pdo);

        // Check practitioner limit
        $stmt = $pdo->prepare("
            SELECT COUNT(*) as cnt FROM clinic_users
            WHERE clinic_id = ? AND status = 'active'
        ");
        $stmt->execute([$ctx->clinicId]);
        $count = (int)$stmt->fetch()['cnt'];
        $max = (int)$ctx->clinic['max_practitioners'];
        if ($max > 0 && $count >= $max) {
            Response::error("Practitioner limit reached ($max). Upgrade your plan or disable an existing account.", 409);
        }

        $body = json_decode(file_get_contents('php://input') ?: '', true);
        $email = trim((string)($body['email'] ?? ''));
        $password = (string)($body['password'] ?? '');
        $role = (string)($body['role'] ?? 'practitioner');

        if ($email === '' || $password === '') {
            Response::error('email and password required', 400);
        }
        if (!filter_var($email, FILTER_VALIDATE_EMAIL)) {
            Response::error('Invalid email address', 400);
        }
        if (strlen($password) < 12) {
            Response::error('Password must be at least 12 characters', 400);
        }
        if (!in_array($role, ['admin', 'practitioner'], true)) {
            Response::error('role must be admin or practitioner', 400);
        }

        $emailLower = strtolower($email);

        // Check for duplicate
        $stmt = $pdo->prepare("SELECT id FROM clinic_users WHERE email_lower = ?");
        $stmt->execute([$emailLower]);
        if ($stmt->fetch()) {
            Response::error('A user with this email already exists', 409);
        }

        $userId = strtolower(substr(bin2hex(random_bytes(16)), 0, 24));
        $hash = CryptoService::hashPassword($password);

        $stmt = $pdo->prepare("
            INSERT INTO clinic_users
                (id, clinic_id, email, email_lower, password_hash, role, status,
                 totp_enabled, created_at)
            VALUES (?, ?, ?, ?, ?, ?, 'active', 0, NOW())
        ");
        $stmt->execute([$userId, $ctx->clinicId, $email, $emailLower, $hash, $role]);

        AuditService::log(
            $pdo, 'create_practitioner', 'create',
            $ctx->clinicId, $ctx->userId, 'user', $userId, true,
            ['email' => $email, 'role' => $role]
        );

        Response::json([
            'id' => $userId,
            'email' => $email,
            'role' => $role,
            'status' => 'active',
        ], 201);
    }

    /**
     * PUT /v1/clinic/admin/practitioners/<id>
     * Update role or status.
     * Body: {role?, status?}
     */
    public static function update(string $targetId): void
    {
        if ($_SERVER['REQUEST_METHOD'] !== 'PUT') {
            Response::error('Method not allowed', 405);
        }

        $pdo = Database::get();
        $ctx = self::requireAdmin($pdo);

        // Verify target belongs to this clinic
        $stmt = $pdo->prepare("
            SELECT id, email, role, status FROM clinic_users
            WHERE id = ? AND clinic_id = ?
        ");
        $stmt->execute([$targetId, $ctx->clinicId]);
        $target = $stmt->fetch();
        if (!$target) Response::notFound();

        // Cannot modify yourself (prevents admin lockout)
        if ($targetId === $ctx->userId) {
            Response::error('Cannot modify your own account through admin panel', 400);
        }

        $body = json_decode(file_get_contents('php://input') ?: '', true);
        $updates = [];
        $params = [];
        $changes = [];

        if (isset($body['role'])) {
            $role = (string)$body['role'];
            if (!in_array($role, ['admin', 'practitioner'], true)) {
                Response::error('role must be admin or practitioner', 400);
            }
            $updates[] = 'role = ?';
            $params[] = $role;
            $changes['role'] = $role;
        }

        if (isset($body['status'])) {
            $status = (string)$body['status'];
            if (!in_array($status, ['active', 'disabled'], true)) {
                Response::error('status must be active or disabled', 400);
            }
            $updates[] = 'status = ?';
            $params[] = $status;
            $changes['status'] = $status;
        }

        if (empty($updates)) {
            Response::error('Nothing to update', 400);
        }

        $params[] = $targetId;
        $pdo->prepare("UPDATE clinic_users SET " . implode(', ', $updates) . " WHERE id = ?")
            ->execute($params);

        AuditService::log(
            $pdo, 'update_practitioner', 'update',
            $ctx->clinicId, $ctx->userId, 'user', $targetId, true,
            $changes
        );

        Response::json(['status' => 'ok', 'changes' => $changes]);
    }

    /**
     * DELETE /v1/clinic/admin/practitioners/<id>
     * Soft-deactivate a practitioner. Sets status='disabled'.
     */
    public static function deactivate(string $targetId): void
    {
        if ($_SERVER['REQUEST_METHOD'] !== 'DELETE') {
            Response::error('Method not allowed', 405);
        }

        $pdo = Database::get();
        $ctx = self::requireAdmin($pdo);

        if ($targetId === $ctx->userId) {
            Response::error('Cannot deactivate your own account', 400);
        }

        $stmt = $pdo->prepare("
            SELECT id, email, status FROM clinic_users
            WHERE id = ? AND clinic_id = ?
        ");
        $stmt->execute([$targetId, $ctx->clinicId]);
        $target = $stmt->fetch();
        if (!$target) Response::notFound();

        if ($target['status'] === 'disabled') {
            Response::json(['status' => 'ok', 'message' => 'Already disabled']);
            return;
        }

        $pdo->prepare("UPDATE clinic_users SET status = 'disabled' WHERE id = ?")
            ->execute([$targetId]);

        // Kill active sessions for this user
        $pdo->prepare("DELETE FROM clinic_sessions WHERE user_id = ?")
            ->execute([$targetId]);

        AuditService::log(
            $pdo, 'deactivate_practitioner', 'update',
            $ctx->clinicId, $ctx->userId, 'user', $targetId, true,
            ['email' => $target['email']]
        );

        Response::json(['status' => 'ok']);
    }
}
