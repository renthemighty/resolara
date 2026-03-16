<?php

class JobsHandler {
    public static function handle(string $jobId = ''): never {
        $method = $_SERVER['REQUEST_METHOD'];

        if ($method === 'GET' && $jobId !== '') {
            self::getJob($jobId);
        }

        if ($method === 'POST' && $jobId === '') {
            self::createJob();
        }

        Response::error('Method not allowed', 405);
    }

    // ── GET /v1/jobs/{id} ─────────────────────────────────────────────────

    private static function getJob(string $jobId): never {
        $device = Auth::require();
        $db     = Database::get();

        $stmt = $db->prepare(
            'SELECT * FROM jobs WHERE id = ? AND device_token = ? LIMIT 1'
        );
        $stmt->execute([$jobId, $device['token']]);
        $job = $stmt->fetch();

        if (!$job) Response::notFound();

        Response::json(self::formatJob($job));
    }

    // ── POST /v1/jobs ─────────────────────────────────────────────────────

    private static function createJob(): never {
        $device = Auth::require();

        if (empty($_FILES['report'])) {
            Response::error('report file is required');
        }

        $file = $_FILES['report'];
        if ($file['error'] !== UPLOAD_ERR_OK) {
            Response::error('Upload error: ' . $file['error']);
        }

        // Enforce file size limit (20 MB)
        if ($file['size'] > 20 * 1024 * 1024) {
            Response::error('File too large. Maximum upload size is 20 MB.', 413);
        }

        // Validate file type by MIME sniff
        $finfo    = new finfo(FILEINFO_MIME_TYPE);
        $mimeType = $finfo->file($file['tmp_name']);
        $allowed  = ['image/jpeg', 'image/png', 'image/webp', 'image/heic', 'application/pdf'];
        if (!in_array($mimeType, $allowed, true)) {
            Response::error('Unsupported file type: ' . $mimeType);
        }

        // Save to storage
        $uploadDir = STORAGE_PATH . '/uploads/';
        $filename  = 'report_' . bin2hex(random_bytes(12)) . '.jpg';
        $destPath  = $uploadDir . $filename;

        if (!move_uploaded_file($file['tmp_name'], $destPath)) {
            Response::error('Failed to save uploaded file', 500);
        }

        // Create job record
        $jobId = Auth::uuid();
        $db    = Database::get();
        $db->prepare(
            'INSERT INTO jobs (id, device_token, status, image_path) VALUES (?, ?, ?, ?)'
        )->execute([$jobId, $device['token'], 'processing', $destPath]);

        // Flush response to client, then process in background
        $responseData = json_encode(['job_id' => $jobId]);
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
            $result = ClaudeService::extractFindings($destPath);
            $db->prepare(
                'UPDATE jobs SET status = ?, result_json = ?, updated_at = NOW() WHERE id = ?'
            )->execute(['completed', json_encode($result), $jobId]);
        } catch (Throwable $e) {
            $db->prepare(
                'UPDATE jobs SET status = ?, error_message = ?, updated_at = NOW() WHERE id = ?'
            )->execute(['failed', $e->getMessage(), $jobId]);
        }

        exit;
    }

    private static function formatJob(array $job): array {
        $result = $job['result_json'] ? json_decode($job['result_json'], true) : null;
        return [
            'job_id' => $job['id'],
            'status' => $job['status'],
            'result' => $result,
            'error'  => $job['error_message'],
        ];
    }
}
