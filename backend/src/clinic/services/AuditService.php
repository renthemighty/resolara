<?php
declare(strict_types=1);

/**
 * AuditService — structured audit log for clinic platform.
 *
 * Every access to PHI, every login/logout/admin action, every share or
 * export, is written here. Retention: 6 years (HIPAA). Partitioning by
 * month is applied in a subsequent migration; the table is append-only
 * by policy (no UPDATEs, no DELETEs outside retention cleanup).
 *
 * `details_encrypted` is envelope-encrypted JSON when details contain PHI
 * (patient name resolved, query text, etc.). Non-PHI details (counts,
 * status codes, resource type) can go in plaintext via a separate
 * `details_plain` column if needed — right now we keep it simple and
 * always encrypt the details blob.
 */
class AuditService
{
    public static function log(
        PDO $pdo,
        string $event,
        string $action,
        ?string $clinicId = null,
        ?string $userId = null,
        ?string $resourceType = null,
        ?string $resourceId = null,
        bool $success = true,
        array $details = []
    ): void {
        $detailsBlob = null;
        if (!empty($details) && $clinicId !== null) {
            try {
                $detailsBlob = self::encryptDetails($pdo, $clinicId, $details);
            } catch (Throwable) {
                // Auditing must never block the request; swallow and move on.
                $detailsBlob = null;
            }
        }

        $stmt = $pdo->prepare("
            INSERT INTO clinic_audit_log
                (clinic_id, user_id, event, resource_type, resource_id, action,
                 ip_address, user_agent_hash, success, details_encrypted)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        ");
        $stmt->execute([
            $clinicId,
            $userId,
            $event,
            $resourceType,
            $resourceId,
            $action,
            self::clientIpBinary(),
            self::userAgentHash(),
            $success ? 1 : 0,
            $detailsBlob,
        ]);
    }

    /**
     * Encrypt details with the clinic's DEK. Looks up the clinic row once
     * per process to get the wrapped DEK + key_id.
     */
    private static function encryptDetails(PDO $pdo, string $clinicId, array $details): string
    {
        require_once __DIR__ . '/CryptoService.php';
        $stmt = $pdo->prepare("SELECT encrypted_dek, dek_key_id FROM clinics WHERE id = ?");
        $stmt->execute([$clinicId]);
        $row = $stmt->fetch();
        if (!$row) {
            throw new RuntimeException("Clinic $clinicId not found for audit encryption");
        }
        $dek = CryptoService::unwrapClinicDek($clinicId, $row['encrypted_dek'], $row['dek_key_id']);
        return CryptoService::encrypt(json_encode($details, JSON_UNESCAPED_UNICODE), $dek);
    }

    private static function clientIpBinary(): ?string
    {
        $ip = $_SERVER['HTTP_X_FORWARDED_FOR'] ?? $_SERVER['REMOTE_ADDR'] ?? '';
        if ($ip === '') return null;
        if (str_contains($ip, ',')) $ip = trim(explode(',', $ip)[0]);
        $packed = @inet_pton($ip);
        return $packed === false ? null : $packed;
    }

    private static function userAgentHash(): ?string
    {
        $ua = $_SERVER['HTTP_USER_AGENT'] ?? '';
        return $ua === '' ? null : hash('sha256', $ua);
    }
}
