<?php
declare(strict_types=1);

require_once __DIR__ . '/../ClinicContext.php';
require_once __DIR__ . '/../services/CryptoService.php';
require_once __DIR__ . '/../services/AuditService.php';

/**
 * ClinicUploadHandler — receives a clinical report PDF, stores it
 * envelope-encrypted, extracts embedded text, and runs AI findings
 * extraction. Also accepts already-OCR'd text submitted by the browser
 * client for scanned PDFs / images (see handleText()).
 *
 * PRIVACY: the raw file bytes handled by handle()/processOcr() below are
 * ONLY ever a PDF (see ALLOWED_MIMES). This endpoint does NOT perform any
 * image-based OCR and does NOT send document pixels to Claude or any other
 * vendor — see extractFromPdf() for why, and see handleText() for how
 * scanned PDFs and images are handled instead (OCR runs client-side in the
 * browser via tesseract.js; only recognized text is ever sent here).
 *
 * POST /v1/clinic/sessions/upload
 *   Content-Type: multipart/form-data
 *   Fields:
 *     file       — the uploaded file (PDF only, ≤50 MB)
 *     patient_id — existing patient ID to associate with this visit
 *
 * Flow:
 *   1. Validate MIME via finfo_file (not Content-Type header — untrustworthy)
 *   2. Stream to temp file with UUID name
 *   3. Create clinic_visits row (status=uploaded)
 *   4. Envelope-encrypt original file to STORAGE_PATH/clinic/<clinic_id>/<visit_id>.enc
 *   5. Run extractReportText() — Ghostscript embedded-text fast path only.
 *      If the PDF has no embedded text layer (i.e. it's a scanned image),
 *      this throws SCANNED_PDF_NO_TEXT_LAYER — the client is expected to
 *      ask the practitioner to export/screenshot pages as images and
 *      resubmit those via handleText() instead.
 *   6. Store extracted text envelope-encrypted in clinic_visits.report_text_encrypted
 *   7. Run AI extraction (Claude) for structured findings — text only, never images
 *   8. Store findings envelope-encrypted
 *   9. Client polls GET /v1/clinic/sessions/<id> for status/findings
 *
 * Long-running — uses fastcgi_finish_request() to flush the visit_id
 * immediately, then processes OCR + AI extraction in background.
 *
 * See also: POST /v1/clinic/sessions/upload-text — handleText() below.
 */
class ClinicUploadHandler
{
    private const MAX_FILE_SIZE = 52428800; // 50 MB
    private const MIN_TEXT_LENGTH = 20;

    // Multipart /upload accepts PDFs only. Images must never be uploaded as
    // raw bytes — they are OCR'd client-side (tesseract.js) and submitted
    // as text via handleText(). This is the fix for a confirmed PHI leak:
    // raw page pixels used to be sent to Claude Vision for OCR here.
    private const ALLOWED_MIMES = [
        'application/pdf',
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
            Response::error("Unsupported file type: $mime. Accepted: PDF only — for images, OCR them in-browser and submit via /v1/clinic/sessions/upload-text.", 415);
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

    /**
     * Accept already-OCR'd report text from the browser client.
     *
     * POST /v1/clinic/sessions/upload-text
     *   Content-Type: application/json
     *   Body:
     *     patient_id          — existing patient ID to associate with this visit
     *     cleaned_report_text — text recognized client-side (tesseract.js) from a
     *                           scanned PDF page or an image; raw image bytes are
     *                           NEVER sent to this endpoint or any other
     *     source_mime         — informational only, e.g. "image/png" (not trusted,
     *                           no file is attached)
     *     original_filename   — informational only, for display purposes
     *
     * This is the privacy-preserving replacement for uploading raw scanned
     * PDFs/images: OCR runs in the practitioner's browser (see
     * lib/platforms/web/services/tesseract_ocr_service.dart) and only the
     * recognized text — never document pixels — reaches this server or
     * Claude.
     */
    public static function handleText(): void
    {
        if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
            Response::error('Method not allowed', 405);
        }

        $pdo = Database::get();
        $ctx = ClinicContext::require($pdo);

        $body = json_decode(file_get_contents('php://input') ?: '', true) ?? [];

        $patientId = trim((string)($body['patient_id'] ?? ''));
        if ($patientId === '') {
            Response::error('patient_id required', 400);
        }
        $stmt = $pdo->prepare("SELECT id FROM patients WHERE id = ? AND clinic_id = ? AND deleted_at IS NULL");
        $stmt->execute([$patientId, $ctx->clinicId]);
        if (!$stmt->fetch()) {
            Response::error('Patient not found', 404);
        }

        $text = trim((string)($body['cleaned_report_text'] ?? ''));
        if (strlen($text) < self::MIN_TEXT_LENGTH) {
            Response::error('cleaned_report_text is required and must contain readable OCR text', 400);
        }

        $sourceMime = trim((string)($body['source_mime'] ?? '')) ?: 'text/plain';
        $originalFilename = trim((string)($body['original_filename'] ?? '')) ?: 'upload';

        // Create visit row — no raw file is ever stored for this path.
        $visitId = self::generateId();
        $retainUntil = date('Y-m-d H:i:s', strtotime('+90 days'));

        $stmt = $pdo->prepare("
            INSERT INTO clinic_visits
                (id, clinic_id, patient_id, practitioner_id, upload_mime,
                 upload_size_bytes, status, retain_until)
            VALUES (?, ?, ?, ?, ?, ?, 'extracting', ?)
        ");
        $stmt->execute([
            $visitId, $ctx->clinicId, $patientId, $ctx->userId,
            $sourceMime, strlen($text), $retainUntil,
        ]);

        $nameEnc = CryptoService::encrypt($originalFilename, $ctx->dek);
        $pdo->prepare("UPDATE clinic_visits SET upload_filename_encrypted = ? WHERE id = ?")
            ->execute([$nameEnc, $visitId]);

        AuditService::log(
            $pdo, 'upload_report', 'create',
            $ctx->clinicId, $ctx->userId, 'visit', $visitId, true,
            ['mime' => $sourceMime, 'size' => strlen($text), 'ocr_method' => 'browser_tesseract']
        );

        Response::json([
            'visit_id' => $visitId,
            'status' => 'extracting',
        ], 202);

        if (function_exists('fastcgi_finish_request')) {
            fastcgi_finish_request();
        }

        self::runFindingsPipeline($pdo, $visitId, $ctx->dek, $text, 'tesseract');
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

            self::runFindingsPipeline($pdo, $visitId, $dek, $ocrResult['text'], $ocrResult['method']);
        } catch (Throwable $e) {
            $pdo->prepare("
                UPDATE clinic_visits SET status = 'failed', error_message = ? WHERE id = ?
            ")->execute([substr($e->getMessage(), 0, 500), $visitId]);
        }
    }

    /**
     * Store report text envelope-encrypted, run AI findings extraction on
     * it, and mark the visit ready. Shared by the PDF fast-path
     * (processOcr, text from Ghostscript) and the browser-OCR path
     * (handleText, text from tesseract.js). Only ever receives text —
     * never image bytes.
     */
    private static function runFindingsPipeline(
        PDO $pdo,
        string $visitId,
        string $dek,
        string $text,
        string $ocrMethod
    ): void {
        try {
            $textEnc = CryptoService::encrypt($text, $dek);
            $pdo->prepare("
                UPDATE clinic_visits
                   SET report_text_encrypted = ?, ocr_method = ?, status = 'extracting'
                 WHERE id = ?
            ")->execute([$textEnc, $ocrMethod, $visitId]);

            $findings = self::extractFindings($text);
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
     * Extract embedded text from a PDF via Ghostscript's txtwrite device
     * (fast path, ~50ms). This is the ONLY server-side text extraction —
     * there is no OCR fallback here.
     *
     * If the PDF has no embedded text layer (i.e. it is a scanned image),
     * this throws SCANNED_PDF_NO_TEXT_LAYER rather than rasterizing pages
     * and sending them anywhere for OCR. The client is responsible for
     * detecting this error and asking the practitioner to export/screenshot
     * the pages as images, which are then OCR'd client-side (tesseract.js)
     * and submitted as text via handleText()/upload-text. This closes a
     * confirmed PHI leak: raw page pixels used to be rasterized and sent to
     * Claude Vision for OCR here, with no BAA in place.
     *
     * All processing stays on OVH Canada (ORIGIN_IP_REDACTED) — no cross-border,
     * no third-party vendor call of any kind.
     *
     * @return array{text: string, method: string, page_count: int}
     */
    private static function extractReportText(string $filePath, string $mime): array
    {
        return self::extractFromPdf($filePath);
    }

    private static function extractFromPdf(string $filePath): array
    {
        // Get page count via Ghostscript
        $countCmd = sprintf(
            'gs -q -dNODISPLAY -dNOSAFER -c "(%s) (r) file runpdfbegin pdfpagecount = quit" 2>/dev/null',
            str_replace(['(', ')'], ['\\(', '\\)'], $filePath)
        );
        $pageCount = max(1, (int)trim((string)shell_exec($countCmd)));

        // Embedded text via Ghostscript txtwrite (fast path)
        $text = shell_exec(sprintf(
            'gs -sBATCH -dNOPAUSE -dQUIET -sDEVICE=txtwrite -sOutputFile=- %s 2>/dev/null',
            escapeshellarg($filePath)
        ));
        if ($text !== null && strlen(trim($text)) > 50) {
            return ['text' => trim($text), 'method' => 'ghostscript', 'page_count' => $pageCount];
        }

        // No embedded text layer — this is a scanned PDF. Do NOT rasterize
        // and send pages anywhere for OCR; the client must re-submit these
        // pages as images via the in-browser OCR path (upload-text).
        throw new RuntimeException('SCANNED_PDF_NO_TEXT_LAYER');
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
