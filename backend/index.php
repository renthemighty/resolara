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
require_once __DIR__ . '/src/handlers/ExplanationHandler.php';
require_once __DIR__ . '/src/handlers/PatientHandler.php';
require_once __DIR__ . '/src/handlers/ShareHandler.php';
require_once __DIR__ . '/src/services/EmailService.php';
require_once __DIR__ . '/src/clinic/handlers/ClinicAuthHandler.php';

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
//
// Two modes:
//   (a) Clinic web app at https://app.resolara.ai sends Origin and needs
//       credentials:true + a specific (non-wildcard) ACAO.
//   (b) Mobile app (iOS/Android) sends bearer Authorization token, no
//       browser Origin → wildcard ACAO is fine.

$origin = $_SERVER['HTTP_ORIGIN'] ?? '';

$clinicWebOrigin = defined('CLINIC_WEB_ORIGIN')
    ? CLINIC_WEB_ORIGIN
    : 'https://app.resolara.ai';

$extraAllowedOrigins = defined('ALLOWED_ORIGINS')
    ? array_filter(array_map('trim', explode(',', ALLOWED_ORIGINS)))
    : [];

if ($origin === $clinicWebOrigin) {
    header('Access-Control-Allow-Origin: ' . $clinicWebOrigin);
    header('Access-Control-Allow-Credentials: true');
    header('Access-Control-Allow-Methods: GET, POST, PUT, DELETE, OPTIONS');
    header('Access-Control-Allow-Headers: Content-Type, X-CSRF-Token, X-Requested-With');
    header('Access-Control-Max-Age: 86400');
    header('Vary: Origin');
} elseif ($origin !== '' && in_array($origin, $extraAllowedOrigins, true)) {
    header('Access-Control-Allow-Origin: ' . $origin);
    header('Access-Control-Allow-Credentials: true');
    header('Access-Control-Allow-Methods: GET, POST, PUT, DELETE, OPTIONS');
    header('Access-Control-Allow-Headers: Content-Type, X-CSRF-Token, X-Requested-With, Authorization');
    header('Vary: Origin');
} elseif (empty($extraAllowedOrigins)) {
    // Mobile clients (no browser Origin) + open-dev fallback
    header('Access-Control-Allow-Origin: *');
    header('Access-Control-Allow-Methods: GET, POST, OPTIONS');
    header('Access-Control-Allow-Headers: Authorization, Content-Type');
}

header('Referrer-Policy: no-referrer');
header('X-Content-Type-Options: nosniff');
header('X-Frame-Options: DENY');
if ((!empty($_SERVER['HTTPS']) && $_SERVER['HTTPS'] !== 'off') || ($_SERVER['HTTP_X_FORWARDED_PROTO'] ?? '') === 'https') {
    header('Strict-Transport-Security: max-age=63072000; includeSubDomains; preload');
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

if ($path === '/v1/explanation') {
    ExplanationHandler::handle();
}

if ($path === '/v1/patient/register') {
    PatientHandler::register();
}

if ($path === '/v1/patient/verify') {
    PatientHandler::verify();
}

if ($path === '/v1/share') {
    ShareHandler::create();
}

if (preg_match('#^/v1/patient/results/([A-Z0-9]{6})$#i', $path, $m)) {
    ShareHandler::results($m[1]);
}

if (preg_match('#^/v1/patient/results/([A-Z0-9]{6})/explanation$#i', $path, $m)) {
    ShareHandler::explanation($m[1]);
}

if (preg_match('#^/v1/patient/results/([A-Z0-9]{6})/exercises$#i', $path, $m)) {
    ShareHandler::exercises($m[1]);
}

if (preg_match('#^/v1/patient/results/([A-Z0-9]{6})/medications$#i', $path, $m)) {
    ShareHandler::medications($m[1]);
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

// ── Clinic v2 (web app at app.resolara.ai) ────────────────────────────────

if ($path === '/v1/clinic/auth/login') {
    ClinicAuthHandler::login();
}
if ($path === '/v1/clinic/auth/mfa-verify') {
    ClinicAuthHandler::mfaVerify();
}
if ($path === '/v1/clinic/auth/logout') {
    ClinicAuthHandler::logout();
}
if ($path === '/v1/clinic/auth/me') {
    ClinicAuthHandler::me();
}

Response::notFound();
