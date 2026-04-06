<?php
declare(strict_types=1);

/**
 * provision_clinic.php — manually provision a new clinic + admin user.
 *
 * Milestone A uses this in place of the WHMCS ServiceActivated webhook.
 * Run on the OVH server:
 *
 *   php cli/provision_clinic.php \
 *       --clinic-name="Smith Physio" \
 *       --admin-email="owner@example-clinic.ca" \
 *       --admin-password="..." \
 *       --tier=starter \
 *       --max-practitioners=2 \
 *       --max-patients=100 \
 *       --max-storage-gb=5
 *
 * Writes to stdout the generated clinic_id + user_id + the decrypted
 * per-clinic DEK id so Simon can pass credentials to the first pilot.
 */

require_once __DIR__ . '/../../../resolara_api/config.php';
require_once __DIR__ . '/../src/Database.php';
require_once __DIR__ . '/../src/clinic/services/CryptoService.php';

// Parse CLI args
$args = [];
foreach (array_slice($argv, 1) as $arg) {
    if (preg_match('/^--([a-z-]+)=(.+)$/', $arg, $m)) {
        $args[$m[1]] = $m[2];
    }
}

$clinicName      = $args['clinic-name'] ?? exitUsage('--clinic-name required');
$adminEmail      = $args['admin-email'] ?? exitUsage('--admin-email required');
$adminPassword   = $args['admin-password'] ?? exitUsage('--admin-password required');
$tier            = $args['tier'] ?? 'starter';
$maxPractitioners = (int)($args['max-practitioners'] ?? 2);
$maxPatients     = (int)($args['max-patients'] ?? 100);
$maxStorageGb    = (int)($args['max-storage-gb'] ?? 5);

if (!in_array($tier, ['starter','standard','pro','enterprise'], true)) {
    exitUsage("--tier must be one of: starter, standard, pro, enterprise");
}
if (!filter_var($adminEmail, FILTER_VALIDATE_EMAIL)) {
    exitUsage('--admin-email not a valid email');
}
if (strlen($adminPassword) < 12) {
    exitUsage('--admin-password must be ≥12 characters');
}

$pdo = Database::get();

// Generate clinic
$clinicId = strtolower(substr(bin2hex(random_bytes(16)), 0, 24));
$dekInfo = CryptoService::generateClinicDek();
$dek = $dekInfo['dek'];
$nameEncrypted = CryptoService::encrypt($clinicName, $dek);

$stmt = $pdo->prepare("
    INSERT INTO clinics
        (id, name_encrypted, tier, encrypted_dek, dek_key_id,
         status, max_practitioners, max_patients, max_storage_gb)
    VALUES (?, ?, ?, ?, ?, 'active', ?, ?, ?)
");
$stmt->execute([
    $clinicId, $nameEncrypted, $tier,
    $dekInfo['encrypted_dek'], $dekInfo['key_id'],
    $maxPractitioners, $maxPatients, $maxStorageGb,
]);

// Generate admin user
$userId = strtolower(substr(bin2hex(random_bytes(16)), 0, 24));
$emailLower = strtolower($adminEmail);
$passwordHash = CryptoService::hashPassword($adminPassword);

$stmt = $pdo->prepare("
    INSERT INTO clinic_users
        (id, clinic_id, email, email_lower, password_hash,
         role, status, totp_enabled)
    VALUES (?, ?, ?, ?, ?, 'admin', 'active', 0)
");
try {
    $stmt->execute([$userId, $clinicId, $adminEmail, $emailLower, $passwordHash]);
} catch (PDOException $e) {
    if (str_contains($e->getMessage(), 'Duplicate entry')) {
        fwrite(STDERR, "Email $adminEmail already exists\n");
        exit(1);
    }
    throw $e;
}

echo "Clinic provisioned:\n";
echo "  clinic_id:  $clinicId\n";
echo "  clinic:     $clinicName\n";
echo "  tier:       $tier\n";
echo "  dek_key_id: {$dekInfo['key_id']}\n";
echo "\n";
echo "Admin user:\n";
echo "  user_id:    $userId\n";
echo "  email:      $adminEmail\n";
echo "  role:       admin\n";
echo "  status:     active\n";
echo "  totp:       disabled (user can enrol from Settings)\n";
echo "\n";
echo "Sign in at: https://app.resolara.ai/login\n";

function exitUsage(string $msg): never {
    fwrite(STDERR, "Error: $msg\n\n");
    fwrite(STDERR, "Usage: php provision_clinic.php \\\n");
    fwrite(STDERR, "  --clinic-name=\"Name\" --admin-email=x@y.ca --admin-password=... \\\n");
    fwrite(STDERR, "  [--tier=starter] [--max-practitioners=2] [--max-patients=100]\n");
    exit(1);
}
