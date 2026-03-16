<?php

class ActivateHandler {
    public static function handle(): never {
        if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
            Response::error('Method not allowed', 405);
        }

        $body = json_decode(file_get_contents('php://input'), true) ?? [];
        $code = trim($body['code'] ?? '');

        if ($code === '') {
            Response::error('Activation code is required');
        }

        $db   = Database::get();
        $stmt = $db->prepare(
            'SELECT * FROM activation_codes WHERE code = ? LIMIT 1'
        );
        $stmt->execute([$code]);
        $row = $stmt->fetch();

        if (!$row) {
            Response::error('Invalid activation code', 403);
        }

        if ($row['activation_count'] >= $row['max_activations']) {
            Response::error('Activation code has reached its limit', 403);
        }

        // Generate token and record device
        $token = Auth::generateToken();
        $db->prepare(
            'INSERT INTO devices (activation_code, token) VALUES (?, ?)'
        )->execute([$code, $token]);

        $db->prepare(
            'UPDATE activation_codes SET activation_count = activation_count + 1 WHERE code = ?'
        )->execute([$code]);

        Response::json(['token' => $token]);
    }
}
