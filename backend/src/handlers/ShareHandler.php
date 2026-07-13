<?php
declare(strict_types=1);

/**
 * ShareHandler — zero-knowledge share blob store (no DB queries).
 *
 * The mobile app encrypts the entire clinical bundle client-side
 * (AES-256-GCM; key travels only in the URL fragment, which is never sent
 * to any server) before it ever reaches this endpoint. This handler stores
 * and returns opaque ciphertext — it cannot read patient_name, findings,
 * explanations, exercises, or medications, and it MUST NOT call any AI
 * service on behalf of a patient (see backend/index.php — no ClaudeService
 * route exists under /v1/patient/*).
 *
 * Files live in STORAGE_PATH/shares/:
 *   {CODE}.json — { code, image_url, encrypted_bundle, schema_version, created_at, expires_at }
 *
 * The share code is generated on the practitioner device (not the server)
 * because the code itself is used as AEAD associated data when encrypting
 * the bundle — binding the ciphertext to its code so a malicious/compromised
 * server cannot swap ciphertext between codes. The server only validates
 * format and uniqueness.
 */
class ShareHandler {

    // ── POST /v1/share (mobile) ──────────────────────────────────────────────
    public static function create(): never {
        if ($_SERVER['REQUEST_METHOD'] !== 'POST') Response::error('Method not allowed.', 405);

        Auth::require();

        $body = json_decode(file_get_contents('php://input'), true) ?? [];
        Response::json(['code' => self::store($body)]);
    }

    /**
     * Core zero-knowledge share storage — shared by the mobile (/v1/share)
     * and clinic-web (/v1/clinic/share) surfaces. Both callers encrypt the
     * clinical bundle client-side (see ShareCrypto/share_crypto.dart) before
     * ever calling this; it validates format/uniqueness only and writes the
     * single shares/{CODE}.json record format that results() serves back to
     * patients. It never sees patient_name, findings, or any other plaintext
     * PHI — callers must not pass any.
     */
    public static function store(array $body): string {
        $imageUrl        = trim((string)($body['image_url'] ?? ''));
        $encryptedBundle = trim((string)($body['encrypted_bundle'] ?? ''));
        $schemaVersion   = (int)($body['schema_version'] ?? 1);
        $code            = strtoupper(trim((string)($body['code'] ?? '')));

        if (!$imageUrl) Response::error('image_url is required.');
        if (!$encryptedBundle) Response::error('encrypted_bundle is required.');
        if (!preg_match('/^[A-Z0-9]{6}$/', $code)) {
            Response::error('A valid 6-character code is required.');
        }

        $dir  = self::sharesDir();
        $path = "$dir/$code.json";

        // The client picked this code (it's bound into the ciphertext as
        // AEAD associated data) — if it's already taken, the client must
        // regenerate a new code, re-encrypt, and retry.
        if (file_exists($path)) {
            Response::error('Code already in use.', 409);
        }

        $payload = [
            'code'             => $code,
            'image_url'        => $imageUrl,
            'encrypted_bundle' => $encryptedBundle,
            'schema_version'   => $schemaVersion,
            'created_at'       => date('c'),
            'expires_at'       => date('c', time() + 365 * 24 * 3600),
        ];

        file_put_contents($path, json_encode($payload, JSON_UNESCAPED_UNICODE), LOCK_EX);

        return $code;
    }

    // ── GET /v1/patient/results/{code} ─────────────────────────────────────
    // Unauthenticated by design (patient has no account) — rate limited
    // below because the 6-char code space is otherwise enumerable.
    public static function results(string $code): never {
        if ($_SERVER['REQUEST_METHOD'] !== 'GET') Response::error('Method not allowed.', 405);

        self::rateLimit();

        $data = self::readShare($code);

        // Opaque ciphertext pass-through — the server cannot read this.
        Response::json([
            'code'             => $data['code'],
            'image_url'        => $data['image_url'] ?? '',
            'encrypted_bundle' => $data['encrypted_bundle'] ?? '',
            'expires_at'       => $data['expires_at'] ?? null,
        ]);
    }

    // ── Helpers ────────────────────────────────────────────────────────────

    private static function sharesDir(): string {
        $dir = rtrim(STORAGE_PATH, '/') . '/shares';
        if (!is_dir($dir)) mkdir($dir, 0750, true);
        return $dir;
    }

    /**
     * File-based sliding-window rate limit for the unauthenticated results
     * endpoint, following the same "count recent attempts, 429 over the
     * limit" shape as JobsHandler::createJob()'s DB-backed limiter — this
     * handler is file-based (no DB), so the counter is a per-IP JSON file
     * instead of a table row. Logs counts only, never the code or content.
     */
    private static function rateLimit(): void {
        $ip = $_SERVER['HTTP_X_FORWARDED_FOR'] ?? $_SERVER['REMOTE_ADDR'] ?? 'unknown';
        $ip = trim(explode(',', $ip)[0]);
        $safeKey = preg_replace('/[^a-zA-Z0-9.:]/', '_', $ip) ?: 'unknown';

        $dir = rtrim(STORAGE_PATH, '/') . '/rate_limits';
        if (!is_dir($dir)) mkdir($dir, 0750, true);
        $path = "$dir/results_$safeKey.json";

        $now    = time();
        $window = 3600; // 1 hour
        $limit  = 20;   // max lookups per IP per hour

        $fp = fopen($path, 'c+');
        if ($fp === false) return; // fail open rather than break the endpoint

        flock($fp, LOCK_EX);
        $raw  = stream_get_contents($fp);
        $hits = $raw ? (json_decode($raw, true) ?: []) : [];
        if (!is_array($hits)) $hits = [];
        $hits = array_values(array_filter($hits, fn($t) => is_int($t) && $t > $now - $window));

        if (count($hits) >= $limit) {
            flock($fp, LOCK_UN);
            fclose($fp);
            error_log("ShareHandler: rate limit exceeded ip={$safeKey} attempts=" . count($hits));
            Response::error('Too many attempts. Please try again later.', 429);
        }

        $hits[] = $now;
        ftruncate($fp, 0);
        rewind($fp);
        fwrite($fp, json_encode($hits));
        flock($fp, LOCK_UN);
        fclose($fp);
    }

    /** Normalise, validate, and read a share file. Responds 404 if missing/expired. */
    private static function readShare(string $code): array {
        $code = strtoupper(preg_replace('/[^A-Za-z0-9]/', '', $code));
        if (strlen($code) !== 6) Response::error('Invalid code.', 400);

        $path = self::sharesDir() . "/$code.json";
        if (!file_exists($path)) Response::error('Code not found or expired.', 404);

        $data = json_decode(file_get_contents($path), true);
        if (!is_array($data)) Response::error('Code not found or expired.', 404);

        if (!empty($data['expires_at']) && strtotime($data['expires_at']) < time()) {
            Response::error('Code not found or expired.', 404);
        }

        return $data;
    }
}
