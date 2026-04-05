<?php
declare(strict_types=1);

/**
 * crypto_selftest.php — verify libsodium + AES-256-GCM + master key config.
 *
 * Run on the OVH server after adding RESOLARA_MASTER_KEY_v1 and
 * RESOLARA_BLIND_INDEX_KEY to config.php.
 *
 *   php cli/crypto_selftest.php
 *
 * Checks each layer and exits with status 0 if all OK, 1 if any fail.
 */

require_once __DIR__ . '/../../../resolara_api/config.php';
require_once __DIR__ . '/../src/clinic/services/CryptoService.php';
require_once __DIR__ . '/../src/clinic/services/BlindIndexService.php';
require_once __DIR__ . '/../src/clinic/services/TotpService.php';

$pass = 0;
$fail = 0;

function check(string $label, bool $ok, string $detail = ''): void {
    global $pass, $fail;
    if ($ok) { $pass++; echo "  PASS  $label\n"; }
    else     { $fail++; echo "  FAIL  $label" . ($detail ? " — $detail" : "") . "\n"; }
}

echo "Resolara clinic crypto self-test\n";
echo "=================================\n\n";

// 1. libsodium available
check('libsodium extension loaded', extension_loaded('sodium'));
check('AES-256-GCM available (AES-NI)', sodium_crypto_aead_aes256gcm_is_available());

// 2. Master key configured
try {
    $info = CryptoService::generateClinicDek();
    check('generateClinicDek() succeeds', true);
    check('encrypted_dek has length', strlen($info['encrypted_dek']) >= 48);
    check('dek is 32 bytes', strlen($info['dek']) === 32);

    // 3. Round-trip envelope encrypt/decrypt
    $plaintext = "Patient: Jane Doe\nDOB: 1974-06-15\nMRN: P12345";
    $encrypted = CryptoService::encrypt($plaintext, $info['dek']);
    check('encrypt produces blob', strlen($encrypted) > strlen($plaintext));
    $decrypted = CryptoService::decrypt($encrypted, $info['dek']);
    check('decrypt round-trips', $decrypted === $plaintext);

    // 4. Decrypt with wrong DEK returns null (not exception)
    $wrongDek = random_bytes(32);
    $fail1 = CryptoService::decrypt($encrypted, $wrongDek);
    check('decrypt rejects wrong DEK', $fail1 === null);

    // 5. Unwrap round-trip
    $unwrapped = CryptoService::unwrapClinicDek(
        'test-clinic-id', $info['encrypted_dek'], $info['key_id']
    );
    check('unwrapClinicDek round-trips', $unwrapped === $info['dek']);
} catch (Throwable $e) {
    check('master key configuration', false, $e->getMessage());
}

// 6. Password hashing
try {
    $hash = CryptoService::hashPassword('test-password-1234');
    check('hashPassword produces argon2id hash', str_starts_with($hash, '$argon2id$'));
    check('verifyPassword accepts correct pw', CryptoService::verifyPassword('test-password-1234', $hash));
    check('verifyPassword rejects wrong pw', !CryptoService::verifyPassword('wrong', $hash));
} catch (Throwable $e) {
    check('password hashing', false, $e->getMessage());
}

// 7. Blind index
try {
    $idx = BlindIndexService::indexesFor('test-clinic', 'first_name', 'Smith');
    check('indexesFor returns ≥1 entries', count($idx) >= 1);
    $q = BlindIndexService::queryIndex('test-clinic', 'first_name', 'smith');
    check('query index matches full-name index', in_array($q, $idx, true));
} catch (Throwable $e) {
    check('blind index', false, $e->getMessage());
}

// 8. TOTP
$secret = TotpService::generateSecret();
check('generateSecret produces 20 bytes', strlen($secret) === 20);
check('base32Encode non-empty', TotpService::base32Encode($secret) !== '');
check('otpauthUri contains issuer', str_contains(
    TotpService::otpauthUri($secret, 'test@example.com'),
    'Resolara%20Clinic'
));

// 9. Random token
$t1 = CryptoService::randomToken();
$t2 = CryptoService::randomToken();
check('randomToken produces unique tokens', $t1 !== $t2);
check('randomToken is url-safe', !str_contains($t1, '+') && !str_contains($t1, '/') && !str_contains($t1, '='));

echo "\n";
echo "Result: $pass passed, $fail failed\n";
exit($fail > 0 ? 1 : 0);
