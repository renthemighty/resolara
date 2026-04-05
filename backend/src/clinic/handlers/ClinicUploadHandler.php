<?php
declare(strict_types=1);

require_once __DIR__ . '/../ClinicContext.php';
require_once __DIR__ . '/../services/CryptoService.php';
require_once __DIR__ . '/../services/AuditService.php';

/**
 * ClinicUploadHandler — receives a clinical report file (PDF or image),
 * stores it envelope-encrypted, runs OCR, extracts findings via AI.
 *
 * POST /v1/clinic/sessions/upload
 *   Content-Type: multipart/form-data
 *   Fields:
 *     file       — the uploaded file (PDF/PNG/JPG/TIFF, ≤50 MB)
 *     patient_id — existing patient ID to associate with this visit
 *
 * Flow:
 *   1. Validate MIME via finfo_file (not Content-Type header — untrustworthy)
 *   2. Stream to temp file with UUID name
 *   3. Create clinic_visits row (status=uploaded)
 *   4. Envelope-encrypt original file to STORAGE_PATH/clinic/<clinic_id>/<visit_id>.enc
 *   5. Run extractReportText() — pdftotext fast path, Tesseract fallback
 *   6. Store extracted text envelope-encrypted in clinic_visits.report_text_encrypted
 *   7. Run AI extraction (Claude) for structured findings
 *   8. Store findings envelope-encrypted
 *   9. Return { visit_id, status, text_length, page_count, findings_count }
 *
 * Long-running — uses fastcgi_finish_request() to flush the visit_id
 * immediately, then processes OCR + AI extraction in background.
 */
class ClinicUploadHandler
{
    private const MAX_FILE_SIZE = 52428800; // 50 MB
    private const ALLOWED_MIMES = [
        'application/pdf',
        'image/png',
        'image/jpeg',
        'image/tiff',
    ];

    public static function handle(): void
    {
        if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
            Response::error('Method not allowed', 405);
        }

        $pdo = Database::get();
        $ctx = ClinicContext::require($pdo);

        // Validate file upload
        if (empty($_FILES['file']) || $_FILES['file']['error'] !== UPLOAD_ERR_OK) {
            $code = $_FILES['file']['error'] ?? UPLOAD_ERR_NO_FILE;
            Response::error('File upload failed (code ' . $code . ')', 400);
        }
        $file = $_FILES['file'];
        if ($file['size'] > self::MAX_FILE_SIZE) {
            Response::error('File exceeds 50 MB limit', 413);
        }

        // Validate MIME by inspecting file magic bytes, not the client header
        $finfo = new finfo(FILEINFO_MIME_TYPE);
        $mime = $finfo->file($file['tmp_name']);
        if (!in_array($mime, self::ALLOWED_MIMES, true)) {
            Response::error("Unsupported file type: $mime. Accepted: PDF, PNG, JPEG, TIFF.", 415);
        }

        // Validate patient_id
        $patientId = trim($_POST['patient_id'] ?? '');
        if ($patientId === '') {
            Response::error('patient_id required', 400);
        }
        $stmt = $pdo->prepare("SELECT id FROM patients WHERE id = ? AND clinic_id = ? AND deleted_at IS NULL");
        $stmt->execute([$patientId, $ctx->clinicId]);
        if (!$stmt->fetch()) {
            Response::error('Patient not found', 404);
        }

        // Create visit row
        $visitId = self::generateId();
        $retainUntil = date('Y-m-d H:i:s', strtotime('+90 days'));

        $stmt = $pdo->prepare("
            INSERT INTO clinic_visits
                (id, clinic_id, patient_id, practitioner_id, upload_mime,
                 upload_size_bytes, status, retain_until)
            VALUES (?, ?, ?, ?, ?, ?, 'uploaded', ?)
        ");
        $stmt->execute([
            $visitId, $ctx->clinicId, $patientId, $ctx->userId,
            $mime, $file['size'], $retainUntil,
        ]);

        // Envelope-encrypt the original file
        $clinicStorageDir = self::clinicStorageDir($ctx->clinicId);
        $encPath = $clinicStorageDir . '/' . $visitId . '.enc';
        $rawContent = file_get_contents($file['tmp_name']);
        $encrypted = CryptoService::encrypt($rawContent, $ctx->dek);
        file_put_contents($encPath, $encrypted);
        unset($rawContent, $encrypted);

        // Encrypt original filename
        $nameEnc = CryptoService::encrypt($file['name'] ?? 'upload', $ctx->dek);
        $pdo->prepare("UPDATE clinic_visits SET upload_filename_encrypted = ? WHERE id = ?")
            ->execute([$nameEnc, $visitId]);

        AuditService::log(
            $pdo, 'upload_report', 'create',
            $ctx->clinicId, $ctx->userId, 'visit', $visitId, true,
            ['mime' => $mime, 'size' => $file['size']]
        );

        // Return visit_id immediately, process OCR + extraction in background
        Response::json([
            'visit_id' => $visitId,
            'status' => 'uploaded',
        ], 202);

        // After response is flushed, continue processing
        if (function_exists('fastcgi_finish_request')) {
            fastcgi_finish_request();
        }

        // Background: OCR + AI extraction
        self::processOcr($pdo, $visitId, $ctx->clinicId, $ctx->dek, $file['tmp_name'], $mime);
    }

    /**
     * Poll a visit's processing status.
     * GET /v1/clinic/sessions/<id>
     */
    public static function status(string $visitId): void
    {
        $pdo = Database::get();
        $ctx = ClinicContext::require($pdo);

        $stmt = $pdo->prepare("
            SELECT id, status, ocr_method, error_message, created_at, updated_at
              FROM clinic_visits
             WHERE id = ? AND clinic_id = ?
        ");
        $stmt->execute([$visitId, $ctx->clinicId]);
        $row = $stmt->fetch();
        if (!$row) Response::notFound();

        $result = [
            'visit_id' => $row['id'],
            'status' => $row['status'],
            'ocr_method' => $row['ocr_method'],
            'error' => $row['error_message'],
            'created_at' => $row['created_at'],
        ];

        // If findings are ready, decrypt and include count
        if (in_array($row['status'], ['ready', 'generating', 'complete'], true)) {
            $fStmt = $pdo->prepare("SELECT findings_encrypted FROM clinic_visits WHERE id = ?");
            $fStmt->execute([$visitId]);
            $fRow = $fStmt->fetch();
            if ($fRow && $fRow['findings_encrypted']) {
                $plain = CryptoService::decrypt($fRow['findings_encrypted'], $ctx->dek);
                if ($plain) {
                    $findings = json_decode($plain, true);
                    $result['findings'] = $findings;
                    $result['findings_count'] = is_array($findings) ? count($findings) : 0;
                }
            }
        }

        Response::json($result);
    }

    // ── Background OCR processing ──────────────────────────────────────────

    private static function processOcr(
        PDO $pdo,
        string $visitId,
        string $clinicId,
        string $dek,
        string $tmpPath,
        string $mime
    ): void {
        try {
            $pdo->prepare("UPDATE clinic_visits SET status = 'ocring' WHERE id = ?")
                ->execute([$visitId]);

            $ocrResult = self::extractReportText($tmpPath, $mime);

            // Store OCR'd text envelope-encrypted
            $textEnc = CryptoService::encrypt($ocrResult['text'], $dek);
            $pdo->prepare("
                UPDATE clinic_visits
                   SET report_text_encrypted = ?, ocr_method = ?, status = 'extracting'
                 WHERE id = ?
            ")->execute([$textEnc, $ocrResult['method'], $visitId]);

            // AI extraction
            $findings = self::extractFindings($ocrResult['text']);
            $findingsEnc = CryptoService::encrypt(json_encode($findings, JSON_UNESCAPED_UNICODE), $dek);
            $pdo->prepare("
                UPDATE clinic_visits
                   SET findings_encrypted = ?, status = 'ready'
                 WHERE id = ?
            ")->execute([$findingsEnc, $visitId]);

        } catch (Throwable $e) {
            $pdo->prepare("
                UPDATE clinic_visits SET status = 'failed', error_message = ? WHERE id = ?
            ")->execute([substr($e->getMessage(), 0, 500), $visitId]);
        }
    }

    /**
     * Extract text from a PDF or image.
     *
     * Strategy:
     *   PDF with embedded text layer → pdftotext (poppler-utils), ~50ms
     *   PDF without text (scanned)   → ImageMagick → Tesseract per page
     *   Image (PNG/JPEG/TIFF)        → Tesseract directly
     *
     * All processing is local on OVH Canada — no cross-border transfer.
     *
     * @return array{text: string, method: string, page_count: int}
     */
    private static function extractReportText(string $filePath, string $mime): array
    {
        if ($mime === 'application/pdf') {
            // Try embedded text layer first (fast path)
            $text = shell_exec('pdftotext -layout ' . escapeshellarg($filePath) . ' - 2>/dev/null');
            if ($text !== null && strlen(trim($text)) > 50) {
                $pages = (int)shell_exec('pdfinfo ' . escapeshellarg($filePath) . ' 2>/dev/null | grep -c "Pages:"');
                if ($pages < 1) $pages = 1;
                return ['text' => trim($text), 'method' => 'pdftotext', 'page_count' => $pages];
            }

            // Scanned PDF — render to images, OCR each page
            $pageCountStr = shell_exec('pdfinfo ' . escapeshellarg($filePath) . ' 2>/dev/null | grep "Pages:" | awk \'{print $2}\'');
            $pageCount = max(1, (int)trim((string)$pageCountStr));
            $fullText = '';
            for ($i = 0; $i < $pageCount; $i++) {
                $imgPath = sys_get_temp_dir() . '/resolara_ocr_' . uniqid() . '.png';
                shell_exec(sprintf(
                    'convert -density 300 %s[%d] -depth 8 -strip -background white -alpha off %s 2>/dev/null',
                    escapeshellarg($filePath), $i, escapeshellarg($imgPath)
                ));
                if (file_exists($imgPath)) {
                    $pageText = shell_exec('tesseract ' . escapeshellarg($imgPath) . ' - -l eng 2>/dev/null');
                    $fullText .= trim((string)$pageText) . "\n\n";
                    @unlink($imgPath);
                }
            }
            return ['text' => trim($fullText), 'method' => 'tesseract', 'page_count' => $pageCount];
        }

        // Direct image OCR
        $text = shell_exec('tesseract ' . escapeshellarg($filePath) . ' - -l eng 2>/dev/null');
        return ['text' => trim((string)$text), 'method' => 'tesseract', 'page_count' => 1];
    }

    /**
     * Send OCR'd report text to Claude for structured findings extraction.
     * Returns an array of findings, each with body_region, description, etc.
     *
     * Uses the existing ClaudeService that the mobile app backend already
     * employs for the same task.
     */
    private static function extractFindings(string $reportText): array
    {
        if (strlen($reportText) < 20) {
            return []; // Not enough text to extract from
        }

        $prompt = <<<PROMPT
Extract all medical findings from this clinical report as a JSON array.
Each finding should have:
- "body_region": the anatomical area (e.g. "lumbar spine", "right knee")
- "description": what was found (e.g. "mild disc desiccation at L4-L5")
- "severity": "normal" | "mild" | "moderate" | "severe"

Return ONLY the JSON array, no other text.

Report:
$reportText
PROMPT;

        try {
            $response = ClaudeService::complete($prompt, 4000);
            $parsed = json_decode($response, true);
            if (is_array($parsed)) {
                return $parsed;
            }
            // Try to extract JSON from response if wrapped in explanation
            if (preg_match('/\[[\s\S]*\]/', $response, $m)) {
                $parsed = json_decode($m[0], true);
                if (is_array($parsed)) return $parsed;
            }
            return [];
        } catch (Throwable) {
            return [];
        }
    }

    // ── Helpers ──────────────────────────────────────────────────────────────

    private static function generateId(): string
    {
        return strtolower(substr(bin2hex(random_bytes(16)), 0, 24));
    }

    private static function clinicStorageDir(string $clinicId): string
    {
        $base = defined('STORAGE_PATH') ? STORAGE_PATH : '/home/DAUSER/resolara_storage';
        $dir = $base . '/clinic/' . $clinicId;
        if (!is_dir($dir)) {
            mkdir($dir, 0750, true);
        }
        return $dir;
    }
}
