<?php
declare(strict_types=1);

/**
 * ShareHandler — file-based share system (no DB queries).
 *
 * Files live in STORAGE_PATH/shares/:
 *   {CODE}.json                      — core share data (image_url, patient_name, findings)
 *   {CODE}_explanation.json          — cached explanation (generated once)
 *   {CODE}_exercises_{phase}.json    — cached exercises per phase
 *   {CODE}_medications.json          — cached medications
 */
class ShareHandler {

    // ── POST /v1/share ─────────────────────────────────────────────────────
    public static function create(): never {
        if ($_SERVER['REQUEST_METHOD'] !== 'POST') Response::error('Method not allowed.', 405);

        Auth::require();

        $body        = json_decode(file_get_contents('php://input'), true) ?? [];
        $imageUrl    = trim((string)($body['image_url']    ?? ''));
        $patientName = trim((string)($body['patient_name'] ?? '')) ?: null;
        $findings    = is_array($body['findings'] ?? null) ? $body['findings'] : [];

        if (!$imageUrl) Response::error('image_url is required.');

        $code = self::generateCode();
        $dir  = self::sharesDir();

        $payload = [
            'code'         => $code,
            'image_url'    => $imageUrl,
            'patient_name' => $patientName,
            'findings'     => $findings,
            'created_at'   => date('c'),
            'expires_at'   => date('c', time() + 365 * 24 * 3600),
        ];

        file_put_contents("$dir/$code.json", json_encode($payload, JSON_UNESCAPED_UNICODE), LOCK_EX);

        Response::json(['code' => $code]);
    }

    // ── GET /v1/patient/results/{code} ─────────────────────────────────────
    public static function results(string $code): never {
        if ($_SERVER['REQUEST_METHOD'] !== 'GET') Response::error('Method not allowed.', 405);

        $data = self::readShare($code);

        // Return only what the app needs for the fast initial load
        Response::json([
            'code'         => $data['code'],
            'image_url'    => $data['image_url'],
            'patient_name' => $data['patient_name'],
        ]);
    }

    // ── POST /v1/patient/results/{code}/explanation ────────────────────────
    public static function explanation(string $code): never {
        if ($_SERVER['REQUEST_METHOD'] !== 'POST') Response::error('Method not allowed.', 405);

        $data     = self::readShare($code);
        $cacheKey = 'explanation';

        if ($cached = self::readCache($data['code'], $cacheKey)) {
            Response::json($cached);
        }

        $findings = $data['findings'] ?? [];
        if (empty($findings)) Response::json(['explanations' => []]);

        $clean = array_map(fn($f) => [
            'id'          => substr(preg_replace('/[^a-zA-Z0-9_-]/', '', (string)($f['id'] ?? '')), 0, 32),
            'body_region' => substr(strip_tags((string)($f['body_region'] ?? '')), 0, 100),
            'finding'     => substr(strip_tags((string)($f['finding'] ?? $f['description'] ?? '')), 0, 500),
            'layman_term' => substr(strip_tags((string)($f['layman_term'] ?? '')), 0, 100),
        ], $findings);

        $findingLines = array_map(function($f) {
            $label = $f['layman_term'] ?: $f['body_region'];
            return "- ID {$f['id']} | {$label}: {$f['finding']}";
        }, $clean);

        $prompt = "You are explaining medical findings to a patient in plain, clear language. The practitioner has reviewed and confirmed these findings.\n\n"
            . "For each finding, write a JSON object with these exact fields:\n"
            . "- id: the finding ID provided\n"
            . "- heading: a clear plain-English name for the condition\n"
            . "- what_it_is: 2-3 sentences in plain language\n"
            . "- why_it_matters: 2-3 sentences on day-to-day impact\n"
            . "- outlook: 1-2 sentences on typical recovery\n\n"
            . "Rules: plain language, no jargon, no specific treatment instructions.\n"
            . "Return ONLY a valid JSON array. No markdown.\n\n"
            . "Confirmed findings:\n" . implode("\n", $findingLines);

        $response = ClaudeService::complete($prompt, maxTokens: 2000);
        $text     = self::stripFences(trim($response['content'] ?? ''));
        $parsed   = json_decode($text, true);

        $result = [];
        if (is_array($parsed)) {
            foreach ($parsed as $e) {
                if (!is_array($e)) continue;
                $result[] = [
                    'id'             => substr(strip_tags((string)($e['id']             ?? '')), 0, 32),
                    'heading'        => substr(strip_tags((string)($e['heading']        ?? '')), 0, 150),
                    'what_it_is'     => substr(strip_tags((string)($e['what_it_is']     ?? '')), 0, 600),
                    'why_it_matters' => substr(strip_tags((string)($e['why_it_matters'] ?? '')), 0, 600),
                    'outlook'        => substr(strip_tags((string)($e['outlook']        ?? '')), 0, 400),
                ];
            }
        }

        $out = ['explanations' => $result];
        self::writeCache($data['code'], $cacheKey, $out);
        Response::json($out);
    }

    // ── POST /v1/patient/results/{code}/exercises ──────────────────────────
    public static function exercises(string $code): never {
        if ($_SERVER['REQUEST_METHOD'] !== 'POST') Response::error('Method not allowed.', 405);

        $data  = self::readShare($code);
        $body  = json_decode(file_get_contents('php://input'), true) ?? [];
        $phase = trim((string)($body['phase'] ?? 'acute'));

        if (!in_array($phase, ['acute', 'subacute', 'rehabilitation'], true)) {
            $phase = 'acute';
        }

        $cacheKey = "exercises_$phase";
        if ($cached = self::readCache($data['code'], $cacheKey)) {
            Response::json($cached);
        }

        $findings = $data['findings'] ?? [];
        if (empty($findings)) Response::json(['exercises' => []]);

        $clean = array_map(fn($f) => [
            'body_region' => substr(strip_tags((string)($f['body_region'] ?? '')), 0, 100),
            'finding'     => substr(strip_tags((string)($f['finding'] ?? $f['description'] ?? '')), 0, 500),
            'layman_term' => substr(strip_tags((string)($f['layman_term'] ?? '')), 0, 100),
        ], $findings);

        $phaseDescriptions = [
            'acute'          => 'acute phase (first 1-2 weeks) — rest, protection, pain management only',
            'subacute'       => 'subacute phase (weeks 2-6) — gentle range of motion, light stretching',
            'rehabilitation' => 'rehabilitation phase (6+ weeks, cleared for activity) — strengthening and functional exercises',
        ];

        $findingLines = array_map(function($f) {
            $label = $f['layman_term'] ?: $f['body_region'];
            return "- {$label}: {$f['finding']}";
        }, $clean);

        $phaseDesc = $phaseDescriptions[$phase];

        $prompt = "You are assisting a licensed physiotherapist reviewing confirmed clinical findings.\n\n"
            . "Recovery phase: {$phaseDesc}\n\n"
            . "Based on the findings and phase below, return appropriate exercise recommendations.\n\n"
            . "IMPORTANT rules:\n"
            . "- If findings include fractures or acute bone injuries in the acute phase, set rest_only=true on ALL exercises.\n"
            . "- Match exercises precisely to the injured body region.\n"
            . "- Keep descriptions clear enough for a patient to follow without supervision.\n\n"
            . "For each exercise return a JSON object with these exact fields:\n"
            . "- id: unique string like \"ex_1\"\n"
            . "- name: short exercise name\n"
            . "- description: 2-3 sentences on how to perform it\n"
            . "- reps_or_duration: e.g. \"Hold 30 seconds, 3 sets\"\n"
            . "- frequency: e.g. \"3 times daily\"\n"
            . "- category: one of: stretch | mobility | strengthening | rest\n"
            . "- rest_only: true only for rest/immobilization items\n"
            . "- youtube_query: precise YouTube search string for a clinical demonstration\n\n"
            . "Return ONLY a valid JSON array. No markdown. Maximum 6 items.\n\n"
            . "Confirmed findings:\n" . implode("\n", $findingLines);

        $response = ClaudeService::complete($prompt, maxTokens: 2000);
        $text     = self::stripFences(trim($response['content'] ?? ''));
        $parsed   = json_decode($text, true);

        $result = [];
        if (is_array($parsed)) {
            foreach ($parsed as $i => $e) {
                if (!is_array($e)) continue;
                $result[] = [
                    'id'               => 'ex_' . ($i + 1),
                    'name'             => substr(strip_tags((string)($e['name']              ?? '')), 0, 100),
                    'description'      => substr(strip_tags((string)($e['description']       ?? '')), 0, 600),
                    'reps_or_duration' => substr(strip_tags((string)($e['reps_or_duration']  ?? '')), 0, 100),
                    'frequency'        => substr(strip_tags((string)($e['frequency']         ?? '')), 0, 100),
                    'category'         => in_array($e['category'] ?? '', ['stretch','mobility','strengthening','rest'], true)
                                            ? $e['category'] : 'stretch',
                    'rest_only'        => (bool)($e['rest_only'] ?? false),
                    'youtube_query'    => substr(strip_tags((string)($e['youtube_query']     ?? '')), 0, 200),
                ];
            }
        }

        $out = ['exercises' => $result];
        self::writeCache($data['code'], $cacheKey, $out);
        Response::json($out);
    }

    // ── POST /v1/patient/results/{code}/medications ────────────────────────
    public static function medications(string $code): never {
        if ($_SERVER['REQUEST_METHOD'] !== 'POST') Response::error('Method not allowed.', 405);

        $data     = self::readShare($code);
        $cacheKey = 'medications';

        if ($cached = self::readCache($data['code'], $cacheKey)) {
            Response::json($cached);
        }

        $findings = $data['findings'] ?? [];
        if (empty($findings)) Response::json(['medications' => []]);

        $clean = array_map(fn($f) => [
            'body_region' => substr(strip_tags((string)($f['body_region'] ?? '')), 0, 100),
            'finding'     => substr(strip_tags((string)($f['finding'] ?? $f['description'] ?? '')), 0, 500),
            'layman_term' => substr(strip_tags((string)($f['layman_term'] ?? '')), 0, 100),
        ], $findings);

        $findingLines = array_map(function($f) {
            $label = $f['layman_term'] ?: $f['body_region'];
            return "- {$label}: {$f['finding']}";
        }, $clean);

        $prompt = "You are assisting a licensed healthcare practitioner reviewing confirmed clinical findings.\n\n"
            . "List medications commonly considered for these conditions. Include OTC and common prescription options.\n\n"
            . "For each medication return a JSON object with these exact fields:\n"
            . "- id: unique string like \"med_1\"\n"
            . "- name: generic medication name\n"
            . "- purpose: one sentence why it is commonly considered\n"
            . "- typical_dosing: general dosing range (e.g. \"400-600 mg, two to three times daily with food\")\n\n"
            . "Return ONLY a valid JSON array. No markdown. Maximum 6 medications.\n\n"
            . "Confirmed findings:\n" . implode("\n", $findingLines);

        $response = ClaudeService::complete($prompt, maxTokens: 1200);
        $text     = self::stripFences(trim($response['content'] ?? ''));
        $parsed   = json_decode($text, true);

        $result = [];
        if (is_array($parsed)) {
            foreach ($parsed as $i => $m) {
                if (!is_array($m)) continue;
                $result[] = [
                    'id'             => 'med_' . ($i + 1),
                    'name'           => substr(strip_tags((string)($m['name']            ?? '')), 0, 100),
                    'purpose'        => substr(strip_tags((string)($m['purpose']         ?? '')), 0, 300),
                    'typical_dosing' => substr(strip_tags((string)($m['typical_dosing']  ?? '')), 0, 200),
                    'ai_suggested'   => true,
                ];
            }
        }

        $out = ['medications' => $result];
        self::writeCache($data['code'], $cacheKey, $out);
        Response::json($out);
    }

    // ── Helpers ────────────────────────────────────────────────────────────

    private static function sharesDir(): string {
        $dir = rtrim(STORAGE_PATH, '/') . '/shares';
        if (!is_dir($dir)) mkdir($dir, 0750, true);
        return $dir;
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

    private static function readCache(string $code, string $key): ?array {
        $path = self::sharesDir() . "/{$code}_{$key}.json";
        if (!file_exists($path)) return null;
        $data = json_decode(file_get_contents($path), true);
        return is_array($data) ? $data : null;
    }

    private static function writeCache(string $code, string $key, array $data): void {
        $path = self::sharesDir() . "/{$code}_{$key}.json";
        file_put_contents($path, json_encode($data, JSON_UNESCAPED_UNICODE), LOCK_EX);
    }

    private static function stripFences(string $text): string {
        $text = preg_replace('/^```(?:json)?\s*/i', '', $text);
        return preg_replace('/\s*```$/', '', $text);
    }

    private static function generateCode(): string {
        $chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
        $dir   = self::sharesDir();
        do {
            $code = '';
            for ($i = 0; $i < 6; $i++) $code .= $chars[random_int(0, strlen($chars) - 1)];
        } while (file_exists("$dir/$code.json"));
        return $code;
    }
}
