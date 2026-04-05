<?php
declare(strict_types=1);

/**
 * BlindIndexService — HMAC-SHA256 prefix indexes for patient search.
 *
 * Patient fields (first_name, last_name, email, external_id) are envelope-
 * encrypted and therefore unsearchable by LIKE. The blind index lets us do
 * equality + prefix matches without decrypting any ciphertext:
 *
 *   - Per-clinic HMAC key, derived from master key + clinic_id
 *   - Normalize input (lowercase, trim)
 *   - For each prefix length 1..8 of the normalized value, emit an index row
 *   - At search time, HMAC the query prefix and SELECT equality on it
 *
 * Trade-off: storage bloat (~8 rows per name) for bounded prefix search.
 * No wildcard / substring search — that would require full-text-index-style
 * tokenization and leak too much structure against encrypted data.
 */
class BlindIndexService
{
    private const MAX_PREFIX_LEN = 8;
    private const INDEX_OUTPUT_BYTES = 12;   // 24 hex chars after bin2hex

    /**
     * Generate blind index entries for a patient field. Returns an array
     * of index strings; caller inserts them into patient_search_index.
     *
     * @return array<string>
     */
    public static function indexesFor(string $clinicId, string $fieldType, string $plaintext): array
    {
        $normalized = mb_strtolower(trim($plaintext), 'UTF-8');
        if ($normalized === '') return [];

        $key = self::clinicHmacKey($clinicId);
        $indexes = [];
        $len = min(self::MAX_PREFIX_LEN, mb_strlen($normalized, 'UTF-8'));
        for ($i = 1; $i <= $len; $i++) {
            $prefix = mb_substr($normalized, 0, $i, 'UTF-8');
            $indexes[] = self::hmac("$fieldType:$prefix", $key);
        }
        // Always emit full-string index too (for exact match)
        $indexes[] = self::hmac("$fieldType:$normalized", $key);
        return array_values(array_unique($indexes));
    }

    /**
     * Blind index for a search query — only emits the single index for
     * the normalized query (exact or prefix match).
     */
    public static function queryIndex(string $clinicId, string $fieldType, string $query): string
    {
        $normalized = mb_strtolower(trim($query), 'UTF-8');
        return self::hmac("$fieldType:$normalized", self::clinicHmacKey($clinicId));
    }

    /**
     * Derive a per-clinic HMAC key from the master key. Uses HKDF-like
     * construction: HMAC(master_key, 'blind-index:' + clinic_id).
     */
    private static function clinicHmacKey(string $clinicId): string
    {
        $envName = 'RESOLARA_BLIND_INDEX_KEY';
        $b64 = getenv($envName);
        if ($b64 === false || $b64 === '') {
            if (defined($envName)) {
                $b64 = constant($envName);
            } else {
                throw new RuntimeException("$envName not configured");
            }
        }
        $rootKey = base64_decode($b64, true);
        if ($rootKey === false || strlen($rootKey) < 32) {
            throw new RuntimeException("$envName must be base64-encoded ≥32 bytes");
        }
        return hash_hmac('sha256', "blind-index:$clinicId", $rootKey, true);
    }

    private static function hmac(string $input, string $key): string
    {
        $mac = hash_hmac('sha256', $input, $key, true);
        return bin2hex(substr($mac, 0, self::INDEX_OUTPUT_BYTES));
    }
}
