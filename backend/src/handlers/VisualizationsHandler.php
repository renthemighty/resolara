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

    private static function getVisualization(string $vizId): never {
        $device = Auth::require();
        $db     = Database::get();

        $stmt = $db->prepare(
            'SELECT * FROM visualizations WHERE id = ? AND device_token = ? LIMIT 1'
        );
        $stmt->execute([$vizId, $device['token']]);
        $viz = $stmt->fetch();

        if (!$viz) Response::notFound();

        // Atomically claim a pending job and start generation in the background.
        if ($viz['status'] === 'pending') {
            $claimed = $db->prepare(
                'UPDATE visualizations SET status = ?, updated_at = NOW() WHERE id = ? AND status = ?'
            );
            $claimed->execute(['processing', $vizId, 'pending']);

            if ($claimed->rowCount() === 1) {
                $viz['status'] = 'processing';
                self::flushAndGenerate($viz, $db);
            }

            // Another concurrent request already claimed it — re-fetch.
            $stmt->execute([$vizId, $device['token']]);
            $viz = $stmt->fetch();
        }

        Response::json(self::formatViz($viz));
    }

    private static function createVisualization(): never {
        $device = Auth::require();
        $body   = json_decode(file_get_contents('php://input'), true) ?? [];

        // The patient name is intentionally DISCARDED here: never stored, never
        // forwarded to any AI vendor. It is a direct HIPAA identifier and has no
        // generative purpose (the name is stamped on-device after generation).
        // Older app builds may still POST `patient_name`; dropping it server-side
        // means a stale client cannot reintroduce the leak.
        $patientName  = '';
        $directPrompt = trim((string)($body['prompt'] ?? ''));

        if ($directPrompt !== '') {
            if (strlen($directPrompt) > 2000) {
                Response::error('Prompt too long. Maximum is 2000 characters.');
            }
            self::enqueue(
                ['__type' => 'prompt', '__prompt' => $directPrompt, '__patient' => $patientName],
                $device['token']
            );
        }

        $findings = $body['findings'] ?? [];
        if (empty($findings) || !is_array($findings)) {
            Response::error('Either findings or prompt is required.');
        }
        if (count($findings) > 20) {
            Response::error('Too many findings. Maximum is 20.');
        }
        $cleanFindings = array_map(fn($f) => [
            'id'          => substr(preg_replace('/[^a-zA-Z0-9_-]/', '', (string)($f['id'] ?? '')), 0, 32),
            'body_region' => substr(strip_tags((string)($f['body_region'] ?? '')), 0, 100),
            'finding'     => substr(strip_tags((string)($f['finding'] ?? '')), 0, 500),
        ], $findings);

        self::enqueue(
            ['__type' => 'findings', '__patient' => $patientName, 'findings' => $cleanFindings],
            $device['token']
        );
    }

    private static function enqueue(array $payload, string $deviceToken): never {
        $vizId = Auth::uuid();
        $db    = Database::get();
        $db->prepare(
            'INSERT INTO visualizations (id, device_token, status, findings_json) VALUES (?, ?, ?, ?)'
        )->execute([$vizId, $deviceToken, 'pending', json_encode($payload)]);

        Response::json(['job_id' => $vizId]);
    }

    private static function flushAndGenerate(array $viz, \PDO $db): never {
        $responseData = json_encode(self::formatViz($viz));
        header('Content-Type: application/json; charset=utf-8');
        header('Content-Length: ' . strlen($responseData));
        header('X-Accel-Buffering: no');
        echo $responseData;

        if (function_exists('fastcgi_finish_request')) {
            fastcgi_finish_request();
        } else {
            ob_flush();
            flush();
        }

        ignore_user_abort(true);
        set_time_limit(180);

        $vizId   = $viz['id'];
        $payload = $viz['findings_json'] ? json_decode($viz['findings_json'], true) : [];
        $type    = $payload['__type'] ?? 'findings';
        $patient = $payload['__patient'] ?? '';

        try {
            if ($type === 'prompt') {
                $filename = OpenAIService::generateFromPrompt($payload['__prompt'] ?? '', $patient);
            } else {
                $filename = OpenAIService::generateVisualization($payload['findings'] ?? [], $patient);
            }
            $db->prepare(
                'UPDATE visualizations SET status = ?, image_filename = ?, updated_at = NOW() WHERE id = ?'
            )->execute(['completed', $filename, $vizId]);
        } catch (Throwable $e) {
            error_log('Visualization ' . $vizId . ' failed: ' . $e->getMessage());
            $db->prepare(
                'UPDATE visualizations SET status = ?, error_message = ?, updated_at = NOW() WHERE id = ?'
            )->execute(['failed', 'Generation failed. Please try again.', $vizId]);
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
