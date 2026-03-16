<?php

class Auth {
    /** Extract and validate Bearer token. Returns device row or null. */
    public static function device(): ?array {
        $header = $_SERVER['HTTP_AUTHORIZATION'] ?? '';
        if (!preg_match('/^Bearer\s+(\S+)$/i', $header, $m)) {
            return null;
        }
        $token = $m[1];
        $db = Database::get();
        $stmt = $db->prepare('SELECT * FROM devices WHERE token = ? LIMIT 1');
        $stmt->execute([$token]);
        $device = $stmt->fetch() ?: null;

        if ($device) {
            // Update last_seen
            $db->prepare('UPDATE devices SET last_seen = NOW() WHERE token = ?')
               ->execute([$token]);
        }
        return $device;
    }

    /** Require a valid device token or halt with 401. */
    public static function require(): array {
        $device = self::device();
        if (!$device) Response::unauthorized();
        return $device;
    }

    /** Generate a secure random token. */
    public static function generateToken(): string {
        return bin2hex(random_bytes(32));
    }

    /** Generate a UUID v4. */
    public static function uuid(): string {
        $bytes = random_bytes(16);
        $bytes[6] = chr((ord($bytes[6]) & 0x0f) | 0x40);
        $bytes[8] = chr((ord($bytes[8]) & 0x3f) | 0x80);
        return vsprintf('%s%s-%s-%s-%s-%s%s%s', str_split(bin2hex($bytes), 4));
    }
}
