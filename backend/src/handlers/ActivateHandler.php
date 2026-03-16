<?php

class ActivateHandler {
    private const MAX_ATTEMPTS   = 10;
    private const WINDOW_MINUTES = 15;

    public static function handle(): never {
        if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
            Response::error('Method not allowed', 405);
        }

        $ip = $_SERVER['REMOTE_ADDR'] ?? 'unknown';
        $db = Database::get();

        // ── Rate limit ────────────────────────────────────────────────────────
        $stmt = $db->prepare(
            'SELECT COUNT(*) FROM activation_attempts
             WHERE ip = ? AND attempted_at > NOW() - INTERVAL ' . self::WINDOW_MINUTES . ' MINUTE'
        );
        $stmt->execute([$ip]);
        if ((int)$stmt->fetchColumn() >= self::MAX_ATTEMPTS) {
            SecurityLog::event('rate_limit', 'Activation rate limit hit', $ip);
            Response::error('Too many activation attempts. Please wait 15 minutes.', 429);
        }

        // Record attempt before processing (counts even invalid requests)
        $db->prepare('INSERT INTO activation_attempts (ip) VALUES (?)')->execute([$ip]);

        $body = json_decode(file_get_contents('php://input'), true) ?? [];
        $code = trim($body['code'] ?? '');

        if ($code === '') {
            Response::error('Activation code is required');
        }

        $stmt = $db->prepare(
            'SELECT * FROM activation_codes WHERE code = ? LIMIT 1'
        );
        $stmt->execute([$code]);
        $row = $stmt->fetch();

        if (!$row) {
            SecurityLog::event('activation_fail', 'Invalid code attempted', $ip);
            Response::error('Invalid activation code', 403);
        }

        if ($row['activation_count'] >= $row['max_activations']) {
            SecurityLog::event('activation_fail', 'Code limit reached', $ip);
            Response::error('Activation code has reached its limit', 403);
        }

        // Generate token — use atomic conditional increment to prevent race condition
        $token = Auth::generateToken();
        $db->prepare(
            'INSERT INTO devices (activation_code, token) VALUES (?, ?)'
        )->execute([$code, $token]);

        $db->prepare(
            'UPDATE activation_codes
             SET activation_count = activation_count + 1
             WHERE code = ? AND activation_count < max_activations'
        )->execute([$code]);

        SecurityLog::event('activation_success', 'Device activated', $ip);
        Response::json(['token' => $token]);
    }
}
