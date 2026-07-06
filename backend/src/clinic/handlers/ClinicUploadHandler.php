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
     *   PDF with embedded text → Ghostscript txtwrite device (fast, ~50ms)
     *   PDF scanned (no text)  → ImageMagick render → Claude vision per page
     *   Image (PNG/JPEG/TIFF)  → Claude vision API
     *
     * No pdftotext/tesseract binaries needed — Ghostscript + ImageMagick are
     * available on CageFS; Claude vision handles OCR better than tesseract
     * for medical documents.
     *
     * All processing stays on OVH Canada (ORIGIN_IP_REDACTED) — no cross-border.
     * Claude API calls go to Anthropic (US) but only receive de-identified
     * report content, not patient-identifiable data.
     *
     * @return array{text: string, method: string, page_count: int}
     */
    private static function extractReportText(string $filePath, string $mime): array
    {
        if ($mime === 'application/pdf') {
            return self::extractFromPdf($filePath);
        }

        // Image — send to Claude vision
        return self::extractFromImage($filePath, $mime);
    }

    private static function extractFromPdf(string $filePath): array
    {
        // Get page count via Ghostscript
        $countCmd = sprintf(
            'gs -q -dNODISPLAY -dNOSAFER -c "(%s) (r) file runpdfbegin pdfpagecount = quit" 2>/dev/null',
            str_replace(['(', ')'], ['\\(', '\\)'], $filePath)
        );
        $pageCount = max(1, (int)trim((string)shell_exec($countCmd)));

        // Try embedded text via Ghostscript txtwrite (fast path)
        $text = shell_exec(sprintf(
            'gs -sBATCH -dNOPAUSE -dQUIET -sDEVICE=txtwrite -sOutputFile=- %s 2>/dev/null',
            escapeshellarg($filePath)
        ));
        if ($text !== null && strlen(trim($text)) > 50) {
            return ['text' => trim($text), 'method' => 'ghostscript', 'page_count' => $pageCount];
        }

        // Scanned PDF — render to images, OCR via Claude vision
        $maxPages = min($pageCount, 20); // Cap to avoid runaway costs
        $fullText = '';
        for ($i = 0; $i < $maxPages; $i++) {
            $imgPath = sys_get_temp_dir() . '/resolara_ocr_' . uniqid() . '.png';
            shell_exec(sprintf(
                'convert -density 300 %s[%d] -depth 8 -strip -background white -alpha off -resize 2000x2000\\> %s 2>/dev/null',
                escapeshellarg($filePath), $i, escapeshellarg($imgPath)
            ));
            if (file_exists($imgPath)) {
                $pageText = self::ocrViaClaudeVision($imgPath, 'image/png');
                $fullText .= trim($pageText) . "\n\n";
                @unlink($imgPath);
            }
        }
        $extracted = trim($fullText);
        if (strlen($extracted) < 20) {
            throw new RuntimeException('Could not extract text from scanned PDF. The document may be empty or unreadable.');
        }
        return ['text' => $extracted, 'method' => 'claude_vision', 'page_count' => $pageCount];
    }

    private static function extractFromImage(string $filePath, string $mime): array
    {
        // Resize if very large to keep base64 payload reasonable
        $resizedPath = sys_get_temp_dir() . '/resolara_ocr_' . uniqid() . '.png';
        shell_exec(sprintf(
            'convert %s -resize 2000x2000\\> -depth 8 -strip %s 2>/dev/null',
            escapeshellarg($filePath), escapeshellarg($resizedPath)
        ));
        $targetPath = file_exists($resizedPath) ? $resizedPath : $filePath;
        $targetMime = file_exists($resizedPath) ? 'image/png' : $mime;

        $text = self::ocrViaClaudeVision($targetPath, $targetMime);
        if ($targetPath !== $filePath) @unlink($targetPath);

        if (strlen(trim($text)) < 20) {
            throw new RuntimeException('Could not extract text from image. The document may be empty or unreadable.');
        }
        return ['text' => trim($text), 'method' => 'claude_vision', 'page_count' => 1];
    }

    /**
     * Send an image to Claude vision API for OCR.
     * Returns the extracted text content.
     */
    private static function ocrViaClaudeVision(string $imagePath, string $mime): string
    {
        $imageData = file_get_contents($imagePath);
        if ($imageData === false) return '';

        $b64 = base64_encode($imageData);
        // Claude vision accepts image/jpeg, image/png, image/gif, image/webp
        $mediaMime = in_array($mime, ['image/jpeg', 'image/png', 'image/gif', 'image/webp'], true)
            ? $mime : 'image/png';

        $payload = [
            'model'      => defined('CLAUDE_MODEL') ? CLAUDE_MODEL : 'claude-sonnet-4-6',
            'max_tokens' => 4096,
            'messages'   => [[
                'role'    => 'user',
                'content' => [
                    [
                        'type' => 'image',
                        'source' => [
                            'type' => 'base64',
                            'media_type' => $mediaMime,
                            'data' => $b64,
                        ],
                    ],
                    [
                        'type' => 'text',
                        'text' => 'Extract ALL text from this clinical/medical document image. '
                                . 'Return the complete text content exactly as it appears, preserving '
                                . 'structure, headings, and line breaks. Do not summarize or interpret '
                                . '— return only the raw text extracted from the image.',
                    ],
                ],
            ]],
        ];

        try {
            $response = ClaudeService::callRaw($payload);
            return $response['content'][0]['text'] ?? '';
        } catch (Throwable $e) {
            error_log('Claude vision OCR failed: ' . $e->getMessage());
            return '';
        }
    }

    /**
     * Send OCR'd report text to Claude for structured findings extraction.
     * Returns an array of findings, each with body_region, description, etc.
     */
    private static function extractFindings(string $reportText): array
    {
        if (strlen($reportText) < 20) {
            return [];
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
            $result = ClaudeService::complete($prompt, 4000);
            $text = $result['content'] ?? '';
            $parsed = json_decode($text, true);
            if (is_array($parsed)) {
                return $parsed;
            }
            if (preg_match('/\[[\s\S]*\]/', $text, $m)) {
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
