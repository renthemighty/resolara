<?php
declare(strict_types=1);
set_time_limit(120);

// ── Bootstrap ─────────────────────────────────────────────────────────────

// Config lives two levels above backend/ (home dir) → ~/resolara_api/config.php
$configFile = dirname(__DIR__, 2) . '/resolara_api/config.php';
if (!file_exists($configFile)) {
    http_response_code(500);
    exit(json_encode(['error' => 'Server not configured']));
}
require_once $configFile;

require_once __DIR__ . '/src/Database.php';
require_once __DIR__ . '/src/Response.php';
require_once __DIR__ . '/src/Auth.php';
require_once __DIR__ . '/src/services/ClaudeService.php';
require_once __DIR__ . '/src/services/OpenAIService.php';
require_once __DIR__ . '/src/SecurityLog.php';
require_once __DIR__ . '/src/handlers/ActivateHandler.php';
require_once __DIR__ . '/src/handlers/JobsHandler.php';
require_once __DIR__ . '/src/handlers/VisualizationsHandler.php';
require_once __DIR__ . '/src/handlers/ImagesHandler.php';
require_once __DIR__ . '/src/handlers/ConfigHandler.php';
require_once __DIR__ . '/src/handlers/LogoutHandler.php';
require_once __DIR__ . '/src/handlers/MedicationsHandler.php';
require_once __DIR__ . '/src/handlers/ExercisesHandler.php';

// ── HTTPS enforcement ─────────────────────────────────────────────────────

if (defined('FORCE_HTTPS') && FORCE_HTTPS) {
    $isHttps = (!empty($_SERVER['HTTPS']) && $_SERVER['HTTPS'] !== 'off')
               || ($_SERVER['SERVER_PORT'] ?? 80) == 443
               || ($_SERVER['HTTP_X_FORWARDED_PROTO'] ?? '') === 'https';
    if (!$isHttps) {
        header('Location: https://' . $_SERVER['HTTP_HOST'] . $_SERVER['REQUEST_URI'], true, 301);
        exit;
    }
}

// ── CORS ──────────────────────────────────────────────────────────────────

$origin         = $_SERVER['HTTP_ORIGIN'] ?? '';
$allowedOrigins = defined('ALLOWED_ORIGINS')
    ? array_map('trim', explode(',', ALLOWED_ORIGINS))
    : [];

if (empty($allowedOrigins)) {
    header('Access-Control-Allow-Origin: *');
} elseif (!empty($origin) && in_array($origin, $allowedOrigins, true)) {
    header('Access-Control-Allow-Origin: ' . $origin);
    header('Vary: Origin');
}

header('Access-Control-Allow-Methods: GET, POST, OPTIONS');
header('Access-Control-Allow-Headers: Authorization, Content-Type');
header('Referrer-Policy: no-referrer');
if ((!empty($_SERVER['HTTPS']) && $_SERVER['HTTPS'] !== 'off') || ($_SERVER['HTTP_X_FORWARDED_PROTO'] ?? '') === 'https') {
    header('Strict-Transport-Security: max-age=31536000; includeSubDomains');
}

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(204);
    exit;
}

// ── Route ─────────────────────────────────────────────────────────────────

$path = parse_url($_SERVER['REQUEST_URI'], PHP_URL_PATH);
$path = '/' . trim($path, '/');

// Strip /api prefix if present (when deployed under /api/)
$path = preg_replace('#^/api#', '', $path);

if ($path === '/v1/config') {
    ConfigHandler::handle();
}

if ($path === '/v1/activate') {
    ActivateHandler::handle();
}

if ($path === '/v1/logout') {
    LogoutHandler::handle();
}

if ($path === '/v1/jobs') {
    JobsHandler::handle();
}

if (preg_match('#^/v1/jobs/([a-f0-9\-]+)$#i', $path, $m)) {
    JobsHandler::handle($m[1]);
}

if ($path === '/v1/medications') {
    MedicationsHandler::handle();
}

if ($path === '/v1/exercises') {
    ExercisesHandler::handle();
}

if ($path === '/v1/visualizations') {
    VisualizationsHandler::handle();
}

if (preg_match('#^/v1/visualizations/([a-f0-9\-]+)$#i', $path, $m)) {
    VisualizationsHandler::handle($m[1]);
}

if (preg_match('#^/v1/images/([a-z0-9_]+)$#i', $path, $m)) {
    ImagesHandler::handle($m[1]);
}

Response::notFound();
