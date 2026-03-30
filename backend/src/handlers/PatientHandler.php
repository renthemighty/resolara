<?php
declare(strict_types=1);

class PatientHandler {

    // ── POST /v1/patient/register ──────────────────────────────────────────────
    // Accepts { email } — creates or finds patient account, sends magic link.

    public static function register(): never {
        if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
            Response::error('Method not allowed', 405);
        }

        $body  = json_decode(file_get_contents('php://input'), true) ?? [];
        $email = strtolower(trim((string)($body['email'] ?? '')));

        if (!filter_var($email, FILTER_VALIDATE_EMAIL)) {
            Response::error('A valid email address is required.');
        }

        $db = Database::get();

        // Rate-limit: max 3 magic links per email per hour
        $stmt = $db->prepare(
            'SELECT COUNT(*) FROM magic_link_tokens
              WHERE email = ? AND created_at > DATE_SUB(NOW(), INTERVAL 1 HOUR)'
        );
        $stmt->execute([$email]);
        if ((int)$stmt->fetchColumn() >= 3) {
            Response::error('Too many login attempts. Please wait before trying again.', 429);
        }

        // Find or create the patient user record
        $stmt = $db->prepare('SELECT id FROM patient_users WHERE email = ? LIMIT 1');
        $stmt->execute([$email]);
        $userId = $stmt->fetchColumn();

        if (!$userId) {
            $userId = Auth::uuid();
            $db->prepare('INSERT INTO patient_users (id, email) VALUES (?, ?)')
               ->execute([$userId, $email]);
        }

        // Generate magic link token (64-char hex)
        $token     = bin2hex(random_bytes(32));
        $expiresAt = date('Y-m-d H:i:s', time() + 1800); // 30 min

        $db->prepare(
            'INSERT INTO magic_link_tokens (id, user_id, email, token, expires_at)
             VALUES (?, ?, ?, ?, ?)'
        )->execute([Auth::uuid(), $userId, $email, $token, $expiresAt]);

        // Send email
        try {
            EmailService::sendMagicLink($email, $token);
        } catch (Throwable $e) {
            error_log('PatientHandler: email failed for ' . $email . ': ' . $e->getMessage());
            Response::error('Could not send login email. Please try again.', 500);
        }

        Response::json(['status' => 'sent', 'email' => $email]);
    }

    // ── GET /v1/patient/verify?token=xxx ─────────────────────────────────────
    // Validates magic link token — returns auth token + role.

    public static function verify(): never {
        $token = trim($_GET['token'] ?? '');

        if (strlen($token) !== 64 || !ctype_xdigit($token)) {
            Response::error('Invalid or missing token.', 400);
        }

        $db   = Database::get();
        $stmt = $db->prepare(
            'SELECT t.id AS tid, t.user_id, t.used_at, t.expires_at, u.email
               FROM magic_link_tokens t
               JOIN patient_users u ON u.id = t.user_id
              WHERE t.token = ?
              LIMIT 1'
        );
        $stmt->execute([$token]);
        $row = $stmt->fetch();

        if (!$row) {
            Response::error('Invalid or expired link.', 401);
        }

        if ($row['used_at'] !== null) {
            Response::error('This link has already been used.', 401);
        }

        if (strtotime($row['expires_at']) < time()) {
            Response::error('This link has expired. Please request a new one.', 401);
        }

        // Mark token as used
        $db->prepare('UPDATE magic_link_tokens SET used_at = NOW() WHERE id = ?')
           ->execute([$row['tid']]);

        // Issue an auth token for this patient (reuse devices table, role=patient)
        $authToken = bin2hex(random_bytes(32));
        $db->prepare(
            'INSERT INTO devices (activation_code, token, role)
             VALUES (?, ?, ?)'
        )->execute(['patient:' . $row['email'], $authToken, 'patient']);

        Response::json([
            'token' => $authToken,
            'role'  => 'patient',
            'email' => $row['email'],
        ]);
    }
}
