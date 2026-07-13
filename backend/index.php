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

define('APP_VERSION', '1.4.1');

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
require_once __DIR__ . '/src/clinic/handlers/ClinicPatientHandler.php';
require_once __DIR__ . '/src/clinic/handlers/ClinicUploadHandler.php';
require_once __DIR__ . '/src/clinic/handlers/ClinicAdminHandler.php';

// ── CORS (MUST be before HTTPS redirect — redirects kill preflight) ──────
// ADC adds Access-Control-Allow-Origin: * and Allow-Methods globally.
// ADC does NOT add Allow-Headers — we add it here.
// Browsers reject redirected OPTIONS preflights, so this block must run
// before any code that could issue a 301/302.

header('Access-Control-Allow-Headers: Content-Type, Authorization, X-CSRF-Token');

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(204);
    exit;
}

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

// NOTE: there is intentionally no /v1/patient/results/{code}/explanation,
// /exercises, or /medications route. Patient-facing content is sealed at
// share time (encrypted client-side by the practitioner's device) and
// decrypted on-device — the server must never generate AI content directly
// for a patient. Do not add a ClaudeService-backed route under /v1/patient/*.

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
if ($path === '/v1/clinic/auth/mfa-setup') {
    ClinicAuthHandler::mfaSetup();
}
if ($path === '/v1/clinic/auth/mfa-confirm') {
    ClinicAuthHandler::mfaConfirm();
}
if ($path === '/v1/clinic/auth/me') {
    ClinicAuthHandler::me();
}

// Patients
if ($path === '/v1/clinic/patients') {
    if ($_SERVER['REQUEST_METHOD'] === 'POST') {
        ClinicPatientHandler::create();
    }
    ClinicPatientHandler::listOrSearch();
}
if (preg_match('#^/v1/clinic/patients/([a-f0-9]{24})$#', $path, $m)) {
    $method = $_SERVER['REQUEST_METHOD'];
    if ($method === 'PUT')    ClinicPatientHandler::update($m[1]);
    if ($method === 'DELETE') ClinicPatientHandler::delete($m[1]);
    ClinicPatientHandler::get($m[1]);
}

// Admin — practitioner management
if ($path === '/v1/clinic/admin/practitioners') {
    if ($_SERVER['REQUEST_METHOD'] === 'POST') {
        ClinicAdminHandler::create();
    }
    ClinicAdminHandler::listPractitioners();
}
if (preg_match('#^/v1/clinic/admin/practitioners/([a-f0-9]{24})$#', $path, $m)) {
    $method = $_SERVER['REQUEST_METHOD'];
    if ($method === 'PUT')    ClinicAdminHandler::update($m[1]);
    if ($method === 'DELETE') ClinicAdminHandler::deactivate($m[1]);
}

// Share (clinic web app — zero-knowledge, same as mobile: the client
// encrypts the bundle before it ever reaches here and picks its own code
// (used as AEAD associated data). This route never sees patient_name or
// findings in plaintext — see ShareHandler::store() for the shared,
// single-source-of-truth storage format both surfaces write.
if ($path === '/v1/clinic/share') {
    if ($_SERVER['REQUEST_METHOD'] !== 'POST') Response::error('Method not allowed', 405);
    $pdo = Database::get();
    $ctx = ClinicContext::require($pdo);
    $body = json_decode(file_get_contents('php://input') ?: '', true) ?? [];
    $code = ShareHandler::store($body);
    AuditService::log($pdo, 'share_created', 'create', $ctx->clinicId, $ctx->userId, 'share', $code, true);
    // No key here — the server never sees it. This bare link is a fallback
    // only; the client must display its own #k=-fragment link built from
    // the key it holds locally.
    Response::json(['code' => $code, 'url' => 'https://resolara.ai/results/' . $code]);
}

// Sessions / visits
if ($path === '/v1/clinic/sessions/upload') {
    ClinicUploadHandler::handle();
}
// Browser-OCR'd text submission (scanned PDFs / images) — see
// ClinicUploadHandler::handleText() docblock. Raw image bytes never reach
// this server; OCR runs client-side via tesseract.js.
if ($path === '/v1/clinic/sessions/upload-text') {
    ClinicUploadHandler::handleText();
}
if (preg_match('#^/v1/clinic/sessions/([a-f0-9]{24})$#', $path, $m)) {
    ClinicUploadHandler::status($m[1]);
}

Response::notFound();
