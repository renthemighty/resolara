<?php

class SecurityLog {
    /**
     * Append a security event to the log file.
     * Log lives outside the web root at LOG_PATH (configured in config.php).
     */
    public static function event(string $type, string $detail, ?string $ip = null): void {
        $ip  = $ip ?? ($_SERVER['REMOTE_ADDR'] ?? 'unknown');
        $line = json_encode([
            'time'   => date('c'),
            'type'   => $type,
            'detail' => $detail,
            'ip'     => $ip,
        ]) . "\n";

        $logDir = defined('LOG_PATH') ? LOG_PATH : dirname(__DIR__, 2) . '/resolara_logs';
        if (!is_dir($logDir)) {
            mkdir($logDir, 0700, true);
        }
        file_put_contents($logDir . '/security.log', $line, FILE_APPEND | LOCK_EX);
    }
}
