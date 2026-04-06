<?php
declare(strict_types=1);

require_once __DIR__ . '/../ClinicContext.php';
require_once __DIR__ . '/../services/CryptoService.php';
require_once __DIR__ . '/../services/BlindIndexService.php';
require_once __DIR__ . '/../services/AuditService.php';

/**
 * ClinicPatientHandler — CRUD + search for clinic patients.
 *
 * All PII fields (first_name, last_name, DOB, email, phone) are stored
 * envelope-encrypted. Search uses blind indexes (HMAC-SHA256 prefix
 * matching via patient_search_index table).
 *
 * Endpoints:
 *   GET    /v1/clinic/patients?q=<search>&limit=20
 *   GET    /v1/clinic/patients/<id>
 *   POST   /v1/clinic/patients          — create new patient
 *   PUT    /v1/clinic/patients/<id>     — update patient fields
 *   DELETE /v1/clinic/patients/<id>     — soft delete (sets deleted_at)
 */
class ClinicPatientHandler
{
    /**
     * GET /v1/clinic/patients — list or search patients.
     *
     * If `q` param is set: blind-index prefix search.
     * If `q` is empty: return most recently created patients (paginated).
     */
    public static function listOrSearch(): void
    {
        $pdo = Database::get();
        $ctx = ClinicContext::require($pdo);

        $query = trim($_GET['q'] ?? '');
        $limit = min(50, max(1, (int)($_GET['limit'] ?? 20)));
        $offset = max(0, (int)($_GET['offset'] ?? 0));

        if ($query !== '' && strlen($query) >= 2) {
            $patients = self::searchByBlindIndex($pdo, $ctx, $query, $limit);
        } else {
            $stmt = $pdo->prepare("
                SELECT id, first_name_encrypted, last_name_encrypted,
                       dob_encrypted, email_encrypted, emr_vendor, created_at
                  FROM patients
                 WHERE clinic_id = ? AND deleted_at IS NULL
                 ORDER BY created_at DESC
                 LIMIT ? OFFSET ?
            ");
            $stmt->execute([$ctx->clinicId, $limit, $offset]);
            $patients = self::decryptRows($stmt->fetchAll(), $ctx->dek);
        }

        $countStmt = $pdo->prepare("SELECT COUNT(*) FROM patients WHERE clinic_id = ? AND deleted_at IS NULL");
        $countStmt->execute([$ctx->clinicId]);
        $total = (int)$countStmt->fetchColumn();

        Response::json([
            'patients' => $patients,
            'total' => $total,
            'limit' => $limit,
            'offset' => $offset,
        ]);
    }

    /**
     * GET /v1/clinic/patients/<id> — single patient with visit history.
     */
    public static function get(string $patientId): void
    {
        $pdo = Database::get();
        $ctx = ClinicContext::require($pdo);

        $stmt = $pdo->prepare("
            SELECT id, first_name_encrypted, last_name_encrypted,
                   dob_encrypted, email_encrypted, phone_encrypted,
                   external_id_encrypted, emr_vendor, created_at
              FROM patients
             WHERE id = ? AND clinic_id = ? AND deleted_at IS NULL
        ");
        $stmt->execute([$patientId, $ctx->clinicId]);
        $row = $stmt->fetch();
        if (!$row) Response::notFound();

        $patient = self::decryptRow($row, $ctx->dek);

        // Recent visits
        $vStmt = $pdo->prepare("
            SELECT id, status, ocr_method, viz_image_url, created_at
              FROM clinic_visits
             WHERE patient_id = ? AND clinic_id = ?
             ORDER BY created_at DESC
             LIMIT 20
        ");
        $vStmt->execute([$patientId, $ctx->clinicId]);
        $patient['visits'] = $vStmt->fetchAll();

        AuditService::log(
            $pdo, 'view_patient', 'read',
            $ctx->clinicId, $ctx->userId, 'patient', $patientId
        );

        Response::json(['patient' => $patient]);
    }

    /**
     * POST /v1/clinic/patients — create a new patient.
     * Body: { first_name, last_name, dob?, email?, phone? }
     */
    public static function create(): void
    {
        if ($_SERVER['REQUEST_METHOD'] !== 'POST') Response::error('Method not allowed', 405);

        $pdo = Database::get();
        $ctx = ClinicContext::require($pdo);

        $body = json_decode(file_get_contents('php://input') ?: '', true) ?? [];
        $firstName = trim((string)($body['first_name'] ?? ''));
        $lastName  = trim((string)($body['last_name'] ?? ''));
        if ($firstName === '' || $lastName === '') {
            Response::error('first_name and last_name required');
        }

        // Check patient limit
        $countStmt = $pdo->prepare("SELECT COUNT(*) FROM patients WHERE clinic_id = ? AND deleted_at IS NULL");
        $countStmt->execute([$ctx->clinicId]);
        $current = (int)$countStmt->fetchColumn();
        if ($current >= (int)$ctx->clinic['max_patients']) {
            Response::error('Patient limit reached for your clinic tier', 403);
        }

        $patientId = self::generateId();

        // Encrypt fields
        $fields = [
            'first_name' => $firstName,
            'last_name'  => $lastName,
            'dob'        => trim((string)($body['dob'] ?? '')),
            'email'      => trim((string)($body['email'] ?? '')),
            'phone'      => trim((string)($body['phone'] ?? '')),
        ];

        $encrypted = [];
        foreach ($fields as $key => $value) {
            $encrypted[$key . '_encrypted'] = $value !== ''
                ? CryptoService::encrypt($value, $ctx->dek)
                : null;
        }

        $stmt = $pdo->prepare("
            INSERT INTO patients
                (id, clinic_id, first_name_encrypted, last_name_encrypted,
                 dob_encrypted, email_encrypted, phone_encrypted, emr_vendor)
            VALUES (?, ?, ?, ?, ?, ?, ?, 'manual')
        ");
        $stmt->execute([
            $patientId, $ctx->clinicId,
            $encrypted['first_name_encrypted'],
            $encrypted['last_name_encrypted'],
            $encrypted['dob_encrypted'],
            $encrypted['email_encrypted'],
            $encrypted['phone_encrypted'],
        ]);

        // Build blind indexes for searchable fields
        self::rebuildSearchIndex($pdo, $ctx->clinicId, $patientId, $fields);

        AuditService::log(
            $pdo, 'create_patient', 'create',
            $ctx->clinicId, $ctx->userId, 'patient', $patientId
        );

        Response::json(['patient_id' => $patientId, 'status' => 'created'], 201);
    }

    /**
     * PUT /v1/clinic/patients/<id> — update a patient's fields.
     * Body: { first_name?, last_name?, dob?, email?, phone? }
     */
    public static function update(string $patientId): void
    {
        if ($_SERVER['REQUEST_METHOD'] !== 'PUT') Response::error('Method not allowed', 405);

        $pdo = Database::get();
        $ctx = ClinicContext::require($pdo);

        $exists = $pdo->prepare("SELECT id FROM patients WHERE id = ? AND clinic_id = ? AND deleted_at IS NULL");
        $exists->execute([$patientId, $ctx->clinicId]);
        if (!$exists->fetch()) Response::notFound();

        $body = json_decode(file_get_contents('php://input') ?: '', true) ?? [];
        $updatable = ['first_name', 'last_name', 'dob', 'email', 'phone'];
        $sets = [];
        $params = [];
        $plaintextFields = [];

        foreach ($updatable as $field) {
            if (array_key_exists($field, $body)) {
                $value = trim((string)$body[$field]);
                $plaintextFields[$field] = $value;
                $col = $field . '_encrypted';
                $sets[] = "$col = ?";
                $params[] = $value !== '' ? CryptoService::encrypt($value, $ctx->dek) : null;
            }
        }

        if (empty($sets)) Response::error('No fields to update');
        $sets[] = 'updated_at = CURRENT_TIMESTAMP';
        $params[] = $patientId;
        $params[] = $ctx->clinicId;

        $sql = "UPDATE patients SET " . implode(', ', $sets) . " WHERE id = ? AND clinic_id = ?";
        $pdo->prepare($sql)->execute($params);

        // Rebuild search indexes if searchable fields changed
        if (!empty($plaintextFields)) {
            // We need ALL current plaintext values to rebuild indexes
            $allFields = self::decryptPatientFields($pdo, $patientId, $ctx->dek);
            foreach ($plaintextFields as $k => $v) {
                $allFields[$k] = $v;
            }
            self::rebuildSearchIndex($pdo, $ctx->clinicId, $patientId, $allFields);
        }

        AuditService::log(
            $pdo, 'update_patient', 'update',
            $ctx->clinicId, $ctx->userId, 'patient', $patientId,
            true, ['fields' => array_keys($plaintextFields)]
        );

        Response::json(['status' => 'updated']);
    }

    /**
     * DELETE /v1/clinic/patients/<id> — soft delete.
     */
    public static function delete(string $patientId): void
    {
        if ($_SERVER['REQUEST_METHOD'] !== 'DELETE') Response::error('Method not allowed', 405);

        $pdo = Database::get();
        $ctx = ClinicContext::require($pdo);

        $stmt = $pdo->prepare("
            UPDATE patients SET deleted_at = CURRENT_TIMESTAMP
             WHERE id = ? AND clinic_id = ? AND deleted_at IS NULL
        ");
        $stmt->execute([$patientId, $ctx->clinicId]);
        if ($stmt->rowCount() === 0) Response::notFound();

        // Remove search indexes
        $pdo->prepare("DELETE FROM patient_search_index WHERE patient_id = ? AND clinic_id = ?")
            ->execute([$patientId, $ctx->clinicId]);

        AuditService::log(
            $pdo, 'delete_patient', 'delete',
            $ctx->clinicId, $ctx->userId, 'patient', $patientId
        );

        Response::json(['status' => 'deleted']);
    }

    // ── Blind-index search ────────────────────────────────────────────────

    private static function searchByBlindIndex(PDO $pdo, ClinicContext $ctx, string $query, int $limit): array
    {
        // Search across first_name and last_name field types
        $firstIdx = BlindIndexService::queryIndex($ctx->clinicId, 'first_name', $query);
        $lastIdx  = BlindIndexService::queryIndex($ctx->clinicId, 'last_name', $query);

        $stmt = $pdo->prepare("
            SELECT DISTINCT p.id, p.first_name_encrypted, p.last_name_encrypted,
                   p.dob_encrypted, p.email_encrypted, p.emr_vendor, p.created_at
              FROM patients p
              JOIN patient_search_index psi ON psi.patient_id = p.id AND psi.clinic_id = p.clinic_id
             WHERE p.clinic_id = ?
               AND p.deleted_at IS NULL
               AND psi.blind_index IN (?, ?)
             LIMIT ?
        ");
        $stmt->execute([$ctx->clinicId, $firstIdx, $lastIdx, $limit]);
        return self::decryptRows($stmt->fetchAll(), $ctx->dek);
    }

    // ── Encryption helpers ──────────────────────────────────────────────────

    private static function decryptRows(array $rows, string $dek): array
    {
        return array_map(fn($r) => self::decryptRow($r, $dek), $rows);
    }

    private static function decryptRow(array $row, string $dek): array
    {
        $out = [
            'id' => $row['id'],
            'emr_vendor' => $row['emr_vendor'] ?? 'manual',
            'created_at' => $row['created_at'] ?? null,
        ];
        $fields = ['first_name', 'last_name', 'dob', 'email', 'phone', 'external_id'];
        foreach ($fields as $f) {
            $col = $f . '_encrypted';
            if (isset($row[$col]) && $row[$col] !== null) {
                $out[$f] = CryptoService::decrypt($row[$col], $dek);
            } else {
                $out[$f] = null;
            }
        }
        // Include visits if present
        if (isset($row['visits'])) $out['visits'] = $row['visits'];
        return $out;
    }

    private static function decryptPatientFields(PDO $pdo, string $patientId, string $dek): array
    {
        $stmt = $pdo->prepare("
            SELECT first_name_encrypted, last_name_encrypted, dob_encrypted,
                   email_encrypted, phone_encrypted
              FROM patients WHERE id = ?
        ");
        $stmt->execute([$patientId]);
        $row = $stmt->fetch();
        if (!$row) return [];

        $fields = [];
        foreach (['first_name', 'last_name', 'dob', 'email', 'phone'] as $f) {
            $enc = $row[$f . '_encrypted'];
            $fields[$f] = ($enc !== null) ? (CryptoService::decrypt($enc, $dek) ?? '') : '';
        }
        return $fields;
    }

    private static function rebuildSearchIndex(PDO $pdo, string $clinicId, string $patientId, array $fields): void
    {
        // Delete existing indexes for this patient
        $pdo->prepare("DELETE FROM patient_search_index WHERE patient_id = ? AND clinic_id = ?")
            ->execute([$patientId, $clinicId]);

        $searchable = [
            'first_name' => $fields['first_name'] ?? '',
            'last_name'  => $fields['last_name'] ?? '',
            'email'      => $fields['email'] ?? '',
        ];

        $stmt = $pdo->prepare("
            INSERT INTO patient_search_index (clinic_id, patient_id, field_type, blind_index)
            VALUES (?, ?, ?, ?)
        ");
        foreach ($searchable as $fieldType => $value) {
            if ($value === '') continue;
            $indexes = BlindIndexService::indexesFor($clinicId, $fieldType, $value);
            foreach ($indexes as $idx) {
                try {
                    $stmt->execute([$clinicId, $patientId, $fieldType, $idx]);
                } catch (PDOException $e) {
                    // Duplicate key = already indexed, ignore
                    if (!str_contains($e->getMessage(), 'Duplicate entry')) throw $e;
                }
            }
        }

        // DOB year index
        $dob = $fields['dob'] ?? '';
        if (preg_match('/^\d{4}/', $dob, $m)) {
            $yearIdx = BlindIndexService::queryIndex($clinicId, 'dob_year', $m[0]);
            try {
                $stmt->execute([$clinicId, $patientId, 'dob_year', $yearIdx]);
            } catch (PDOException) {
                // ignore duplicate
            }
        }
    }

    private static function generateId(): string
    {
        return strtolower(substr(bin2hex(random_bytes(16)), 0, 24));
    }
}
