<?php

class VisualizationsHandler {
    public static function handle(string $vizId = ''): never {
        $method = $_SERVER['REQUEST_METHOD'];

        if ($method === 'GET' && $vizId !== '') {
            self::getVisualization($vizId);
        }

        if ($method === 'POST' && $vizId === '') {
            self::createVisualization();
        }

        Response::error('Method not allowed', 405);
    }

    // ── GET /v1/visualizations/{id} ───────────────────────────────────────

    private static function getVisualization(string $vizId): never {
        $device = Auth::require();
        $db     = Database::get();

        $stmt = $db->prepare(
            'SELECT * FROM visualizations WHERE id = ? AND device_token = ? LIMIT 1'
        );
        $stmt->execute([$vizId, $device['token']]);
        $viz = $stmt->fetch();

        if (!$viz) Response::notFound();

        Response::json(self::formatViz($viz));
    }

    // ── POST /v1/visualizations ───────────────────────────────────────────

    private static function createVisualization(): never {
        $device = Auth::require();
        $body   = json_decode(file_get_contents('php://input'), true) ?? [];

        $findings = $body['findings'] ?? [];
        if (empty($findings) || !is_array($findings)) {
            Response::error('findings array is required');
        }

        // Strip any fields we don't need — keep only body_region and finding text
        $cleanFindings = array_map(fn($f) => [
            'id'          => $f['id']          ?? '',
            'body_region' => $f['body_region']  ?? '',
            'finding'     => $f['finding']      ?? '',
        ], $findings);

        $vizId = Auth::uuid();
        $db    = Database::get();
        $db->prepare(
            'INSERT INTO visualizations (id, device_token, status, findings_json) VALUES (?, ?, ?, ?)'
        )->execute([$vizId, $device['token'], 'processing', json_encode($cleanFindings)]);

        // Flush response, process in background
        $responseData = json_encode(['job_id' => $vizId]);
        header('Content-Type: application/json; charset=utf-8');
        header('Content-Length: ' . strlen($responseData));
        echo $responseData;

        if (function_exists('fastcgi_finish_request')) {
            fastcgi_finish_request();
        } else {
            ob_flush();
            flush();
        }

        // ── Background processing ─────────────────────────────────────────
        ignore_user_abort(true);
        set_time_limit(120);

        try {
            $filename = OpenAIService::generateVisualization($cleanFindings);
            $db->prepare(
                'UPDATE visualizations SET status = ?, image_filename = ?, updated_at = NOW() WHERE id = ?'
            )->execute(['completed', $filename, $vizId]);
        } catch (Throwable $e) {
            $db->prepare(
                'UPDATE visualizations SET status = ?, error_message = ?, updated_at = NOW() WHERE id = ?'
            )->execute(['failed', $e->getMessage(), $vizId]);
        }

        exit;
    }

    private static function formatViz(array $viz): array {
        $imageUrl = null;
        if ($viz['image_filename'] && $viz['status'] === 'completed') {
            $nameWithoutExt = pathinfo($viz['image_filename'], PATHINFO_FILENAME);
            $imageUrl = API_BASE_URL . '/v1/images/' . $nameWithoutExt;
        }
        return [
            'job_id'    => $viz['id'],
            'status'    => $viz['status'],
            'image_url' => $imageUrl,
            'error'     => $viz['error_message'],
        ];
    }
}
