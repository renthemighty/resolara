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
 *   {CODE}.json — { code, image_filename, image_token_hash, encrypted_bundle,
 *                    schema_version, created_at, expires_at }
 *
 * The share code is generated on the practitioner device (not the server)
 * because the code itself is used as AEAD associated data when encrypting
 * the bundle — binding the ciphertext to its code so a malicious/compromised
 * server cannot swap ciphertext between codes. The server only validates
 * format and uniqueness.
 *
 * Image protection (H5 fix): the visualization image is now as protected as
 * the rest of the bundle. results() never returns a usable image reference
 * in cleartext — not even the filename. Instead the caller (practitioner
 * device, at share-creation time) generates its own high-entropy opaque
 * `image_access_token` and passes it alongside `image_filename`. The server
 * stores only a SHA-256 hash of that token (never the token itself) plus a
 * token->filename lookup pointer (see imageTokensDir()). The client is
 * expected to put `image_filename` + `image_access_token` INSIDE the
 * plaintext it encrypts into `encrypted_bundle` — so only someone who can
 * decrypt the bundle (i.e. holds the URL-fragment key) ever learns them.
 * ImagesHandler::handle() accepts that token via `?t=` as an alternative to
 * device Bearer auth, gated by the same hash. A bare 6-char code — even an
 * enumerated one — now yields no image reference at all.
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
     *
     * `image_filename` / `image_access_token` are OPTIONAL and, if present,
     * describe the already-generated visualization. `image_access_token`
     * must be a high-entropy opaque secret the CALLER generates (>= 32
     * chars) — the server only ever persists its SHA-256 hash. The caller
     * is responsible for also placing `image_filename` and
     * `image_access_token` inside the plaintext it encrypts into
     * `encrypted_bundle`, so a patient can only learn them by decrypting
     * the bundle with the URL-fragment key. See ImagesHandler::handle().
     */
    public static function store(array $body): string {
        $encryptedBundle = trim((string)($body['encrypted_bundle'] ?? ''));
        $schemaVersion   = (int)($body['schema_version'] ?? 1);
        $code            = strtoupper(trim((string)($body['code'] ?? '')));
        $imageFilename   = trim((string)($body['image_filename'] ?? ''));
        $imageToken      = trim((string)($body['image_access_token'] ?? ''));

        if (!$encryptedBundle) Response::error('encrypted_bundle is required.');
        if (!preg_match('/^[A-Z0-9]{6}$/', $code)) {
            Response::error('A valid 6-character code is required.');
        }
        if ($imageFilename !== '' && !preg_match('/^[a-z0-9_]+$/i', $imageFilename)) {
            Response::error('Invalid image_filename.');
        }
        // Both or neither — a filename with no token (or vice versa) would
        // leave the image either unreachable or ungated.
        if (($imageFilename !== '') !== ($imageToken !== '')) {
            Response::error('image_filename and image_access_token must be provided together.');
        }
        if ($imageToken !== '' && strlen($imageToken) < 32) {
            Response::error('image_access_token is too short.');
        }

        $dir  = self::sharesDir();
        $path = "$dir/$code.json";

        // The client picked this code (it's bound into the ciphertext as
        // AEAD associated data) — if it's already taken, the client must
        // regenerate a new code, re-encrypt, and retry.
        if (file_exists($path)) {
            Response::error('Code already in use.', 409);
        }

        $expiresAt = date('c', time() + 365 * 24 * 3600);

        $payload = [
            'code'             => $code,
            'encrypted_bundle' => $encryptedBundle,
            'schema_version'   => $schemaVersion,
            'created_at'       => date('c'),
            'expires_at'       => $expiresAt,
        ];

        if ($imageFilename !== '') {
            $tokenHash = hash('sha256', $imageToken);
            $payload['image_filename']    = $imageFilename;
            $payload['image_token_hash']  = $tokenHash;

            // O(1) lookup pointer for ImagesHandler — keyed by the token's
            // own hash so possession of the token is required to find it.
            // Never stores the token itself.
            $tokDir = self::imageTokensDir();
            file_put_contents(
                "$tokDir/$tokenHash.json",
                json_encode(['image_filename' => $imageFilename, 'expires_at' => $expiresAt], JSON_UNESCAPED_UNICODE),
                LOCK_EX
            );
        }

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
        // NOTE (H5 fix): image_filename / image_access_token are never
        // returned here, even for legacy records that still have a plain
        // image_url on disk. The image is only reachable by decrypting
        // encrypted_bundle with the URL-fragment key — a bare code (even
        // one obtained by bypassing the rate limit) gets nothing usable.
        Response::json([
            'code'             => $data['code'],
            'encrypted_bundle' => $data['encrypted_bundle'] ?? '',
            'expires_at'       => $data['expires_at'] ?? null,
        ]);
    }

    /**
     * Looked up by ImagesHandler::handle() via ?t=<image_access_token>.
     * Returns the stored image_filename if the token's hash matches a
     * live (non-expired) pointer, else null. The token itself is never
     * persisted — only its SHA-256 hash — so this is a hash lookup, not a
     * string comparison, which sidesteps timing-attack concerns for the
     * secret-bearing part of the check.
     */
    public static function imageFilenameForToken(string $token): ?string {
        if (strlen($token) < 32) return null;

        $path = self::imageTokensDir() . '/' . hash('sha256', $token) . '.json';
        if (!file_exists($path)) return null;

        $data = json_decode((string)file_get_contents($path), true);
        if (!is_array($data) || empty($data['image_filename'])) return null;

        if (!empty($data['expires_at']) && strtotime($data['expires_at']) < time()) {
            return null;
        }

        return $data['image_filename'];
    }

    // ── Helpers ────────────────────────────────────────────────────────────

    private static function sharesDir(): string {
        $dir = rtrim(STORAGE_PATH, '/') . '/shares';
        if (!is_dir($dir)) mkdir($dir, 0750, true);
        return $dir;
    }

    /** Token->filename lookup pointers for the H5 image-gating fix. */
    private static function imageTokensDir(): string {
        $dir = rtrim(STORAGE_PATH, '/') . '/shares/image_tokens';
        if (!is_dir($dir)) mkdir($dir, 0750, true);
        return $dir;
    }

    // The single reverse proxy resolara.ai sits behind — see Primer.md
    // ("resolara.ai DNS -> LiteSpeed ADC at 142.127.73.40, not directly to
    // ORIGIN_IP_REDACTED"). REMOTE_ADDR at the origin is always this proxy's IP,
    // so per-IP limiting MUST read X-Forwarded-For — but only the hop the
    // proxy itself appended (the right-most entry), never the raw
    // client-supplied left-most value, which is exactly what made H4
    // trivially bypassable. If REMOTE_ADDR is ever something other than
    // this known proxy (local testing, topology change), XFF is untrusted
    // and REMOTE_ADDR is used directly.
    private const TRUSTED_PROXY_IPS = ['142.127.73.40'];

    /** Best-effort *real* client identity for rate limiting (see above). */
    private static function clientIp(): string {
        $remote = $_SERVER['REMOTE_ADDR'] ?? '';
        if ($remote !== '' && in_array($remote, self::TRUSTED_PROXY_IPS, true)
            && !empty($_SERVER['HTTP_X_FORWARDED_FOR'])) {
            $hops = array_map('trim', explode(',', (string)$_SERVER['HTTP_X_FORWARDED_FOR']));
            $hops = array_values(array_filter($hops, fn($h) => $h !== ''));
            if ($hops) {
                // Right-most = appended by our trusted proxy = the peer IP
                // it actually saw, not anything the client injected.
                return end($hops);
            }
        }
        return $remote !== '' ? $remote : 'unknown';
    }

    /**
     * File-based sliding-window rate limit for the unauthenticated results
     * endpoint, following the same "count recent attempts, 429 over the
     * limit" shape as JobsHandler::createJob()'s DB-backed limiter — this
     * handler is file-based (no DB), so the counter is a per-IP JSON file
     * instead of a table row. Logs counts only, never the code or content.
     *
     * H4 fix:
     *  - identity is clientIp() (real peer via trusted-proxy XFF), not the
     *    raw client-supplied header — closes the "send a random XFF, get a
     *    fresh bucket" bypass.
     *  - fails CLOSED: any inability to open/lock/read the counter file now
     *    denies the request (429) instead of silently allowing it through.
     *  - a GLOBAL ceiling across all IPs is enforced in addition to the
     *    per-IP one, capping distributed / botnet-style enumeration that
     *    per-IP limits alone can't stop.
     */
    private static function rateLimit(): void {
        $ip      = self::clientIp();
        $safeKey = preg_replace('/[^a-zA-Z0-9.:]/', '_', $ip) ?: 'unknown';

        $dir = rtrim(STORAGE_PATH, '/') . '/rate_limits';
        if (!is_dir($dir) && !mkdir($dir, 0750, true) && !is_dir($dir)) {
            error_log('ShareHandler: rate_limits dir unavailable — failing closed');
            Response::error('Too many attempts. Please try again later.', 429);
        }

        $now = time();

        self::enforceWindow("$dir/results_$safeKey.json", $now, 3600, 20, "ip={$safeKey}");
        self::enforceWindow("$dir/results_GLOBAL.json", $now, 3600, 500, 'GLOBAL');
    }

    /**
     * Shared sliding-window counter used for both the per-IP and the global
     * ceiling. Opens/locks/reads/increments one counter file; denies
     * (429, fail-closed) on any I/O failure or when the limit is exceeded.
     */
    private static function enforceWindow(string $path, int $now, int $window, int $limit, string $logKey): void {
        $fp = fopen($path, 'c+');
        if ($fp === false) {
            error_log("ShareHandler: rate limit file unavailable ($logKey) — failing closed");
            Response::error('Too many attempts. Please try again later.', 429);
        }

        if (!flock($fp, LOCK_EX)) {
            fclose($fp);
            error_log("ShareHandler: rate limit lock failed ($logKey) — failing closed");
            Response::error('Too many attempts. Please try again later.', 429);
        }

        $raw  = stream_get_contents($fp);
        $hits = $raw ? json_decode($raw, true) : [];
        if (!is_array($hits)) $hits = []; // corrupt file — treat as empty, don't fail open on parse errors
        $hits = array_values(array_filter($hits, fn($t) => is_int($t) && $t > $now - $window));

        if (count($hits) >= $limit) {
            flock($fp, LOCK_UN);
            fclose($fp);
            error_log("ShareHandler: rate limit exceeded ($logKey) attempts=" . count($hits));
            Response::error('Too many attempts. Please try again later.', 429);
        }

        $hits[] = $now;
        ftruncate($fp, 0);
        rewind($fp);
        fwrite($fp, json_encode($hits));
        fflush($fp);
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
