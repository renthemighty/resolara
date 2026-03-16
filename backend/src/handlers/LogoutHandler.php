<?php

class LogoutHandler {
    public static function handle(): never {
        if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
            Response::error('Method not allowed', 405);
        }

        $device = Auth::device();
        if ($device) {
            $db = Database::get();
            $db->prepare('DELETE FROM devices WHERE token = ?')
               ->execute([$device['token']]);
            SecurityLog::event('logout', 'Device logged out (id:' . $device['id'] . ')', $_SERVER['REMOTE_ADDR'] ?? '');
        }

        Response::json(['ok' => true]);
    }
}
