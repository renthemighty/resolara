-- ============================================================================
-- Resolara Clinic Platform — Initial Schema (v2, Milestone A)
-- ============================================================================
-- Creates all tables for the hosted web clinic platform.
--
-- Field-level envelope encryption:
--   Master Key (env var, rotated yearly)
--     ─► Per-Clinic DEK (32 bytes, wrapped with master via sodium secretbox,
--        stored in clinics.encrypted_dek)
--         ─► Per-Record encrypted BLOB
--            Format: nonce(12) || ciphertext || tag(16)
--            Cipher: crypto_aead_aes256gcm via libsodium
--
-- Fields stored plaintext (for query / indexing / FK):
--   - IDs, timestamps, status enums, non-PHI metadata
--
-- Fields encrypted BLOB:
--   - Patient PII (name, DOB, email, phone, external_id)
--   - Clinical content (report_text, findings, viz prompts)
--   - EMR credentials (tokens)
--   - Clinic + user identity metadata (name, email on clinic_users)
--
-- Run with:
--   mysql -u DAUSER_resolara '-p***REMOVED***' DAUSER_resolara \
--     < 001_clinic_platform.sql
-- ============================================================================

-- ── Clinics ────────────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS clinics (
  id VARCHAR(32) NOT NULL PRIMARY KEY,
  name_encrypted BLOB NOT NULL,
  whmcs_client_id INT UNSIGNED NULL,
  whmcs_service_id INT UNSIGNED NULL,
  tier ENUM('starter','standard','pro','enterprise') NOT NULL DEFAULT 'starter',
  encrypted_dek BLOB NOT NULL,
  dek_key_id VARCHAR(64) NOT NULL,
  status ENUM('active','suspended','cancelled') NOT NULL DEFAULT 'active',
  max_practitioners INT UNSIGNED NOT NULL DEFAULT 2,
  max_patients INT UNSIGNED NOT NULL DEFAULT 100,
  max_storage_gb INT UNSIGNED NOT NULL DEFAULT 5,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  INDEX idx_clinic_status (status),
  INDEX idx_clinic_whmcs (whmcs_service_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ── Clinic users (practitioners + admins + assistants) ─────────────────────

CREATE TABLE IF NOT EXISTS clinic_users (
  id VARCHAR(32) NOT NULL PRIMARY KEY,
  clinic_id VARCHAR(32) NOT NULL,
  email VARCHAR(255) NOT NULL,
  email_lower VARCHAR(255) NOT NULL,
  password_hash VARCHAR(255) NOT NULL,
  name_encrypted BLOB NULL,
  role ENUM('admin','practitioner','assistant') NOT NULL DEFAULT 'practitioner',
  totp_secret_encrypted BLOB NULL,
  totp_enabled TINYINT(1) NOT NULL DEFAULT 0,
  status ENUM('active','disabled','invited') NOT NULL DEFAULT 'invited',
  last_login_at DATETIME NULL,
  failed_login_count INT UNSIGNED NOT NULL DEFAULT 0,
  locked_until DATETIME NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  UNIQUE KEY uq_email_lower (email_lower),
  INDEX idx_user_clinic (clinic_id, status),
  CONSTRAINT fk_user_clinic FOREIGN KEY (clinic_id) REFERENCES clinics(id) ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ── Clinic sessions (httpOnly cookie-backed) ───────────────────────────────

CREATE TABLE IF NOT EXISTS clinic_sessions (
  token_hash VARCHAR(128) NOT NULL PRIMARY KEY,
  user_id VARCHAR(32) NOT NULL,
  clinic_id VARCHAR(32) NOT NULL,
  csrf_token VARCHAR(64) NOT NULL,
  ip_address VARBINARY(16) NULL,
  user_agent_hash VARCHAR(64) NULL,
  expires_at DATETIME NOT NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  last_active_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  pending_mfa TINYINT(1) NOT NULL DEFAULT 0,
  INDEX idx_session_expires (expires_at),
  INDEX idx_session_user (user_id),
  CONSTRAINT fk_session_user FOREIGN KEY (user_id) REFERENCES clinic_users(id) ON DELETE CASCADE,
  CONSTRAINT fk_session_clinic FOREIGN KEY (clinic_id) REFERENCES clinics(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ── Licences (account-bound, Ed25519 signed file for audit/entitlement) ────

CREATE TABLE IF NOT EXISTS clinic_licenses (
  id VARCHAR(32) NOT NULL PRIMARY KEY,
  clinic_id VARCHAR(32) NOT NULL,
  license_key VARCHAR(24) NOT NULL,
  tier VARCHAR(32) NOT NULL,
  features JSON NOT NULL,
  issued_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  expires_at DATETIME NOT NULL,
  status ENUM('issued','active','grace','expired','revoked','suspended') NOT NULL DEFAULT 'issued',
  signing_key_id VARCHAR(64) NOT NULL,
  signed_payload LONGTEXT NULL,
  UNIQUE KEY uq_license_key (license_key),
  INDEX idx_license_clinic (clinic_id, status),
  CONSTRAINT fk_license_clinic FOREIGN KEY (clinic_id) REFERENCES clinics(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ── Patients (PHI, field-level envelope encryption) ────────────────────────

CREATE TABLE IF NOT EXISTS patients (
  id VARCHAR(32) NOT NULL PRIMARY KEY,
  clinic_id VARCHAR(32) NOT NULL,
  first_name_encrypted BLOB NULL,
  last_name_encrypted BLOB NULL,
  dob_encrypted BLOB NULL,
  email_encrypted BLOB NULL,
  phone_encrypted BLOB NULL,
  external_id_encrypted BLOB NULL,
  external_id_hash VARCHAR(64) NULL,
  emr_vendor ENUM('jane','cliniko','fhir','cerbo','manual') NOT NULL DEFAULT 'manual',
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  deleted_at DATETIME NULL,
  INDEX idx_patient_clinic (clinic_id, deleted_at),
  INDEX idx_patient_external (clinic_id, emr_vendor, external_id_hash),
  CONSTRAINT fk_patient_clinic FOREIGN KEY (clinic_id) REFERENCES clinics(id) ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ── Patient search blind index (HMAC-SHA256 prefix lookups) ────────────────

CREATE TABLE IF NOT EXISTS patient_search_index (
  clinic_id VARCHAR(32) NOT NULL,
  patient_id VARCHAR(32) NOT NULL,
  field_type ENUM('first_name','last_name','email','external_id','dob_year') NOT NULL,
  blind_index VARCHAR(64) NOT NULL,
  PRIMARY KEY (clinic_id, patient_id, field_type, blind_index),
  INDEX idx_blind_search (clinic_id, field_type, blind_index),
  CONSTRAINT fk_psi_patient FOREIGN KEY (patient_id) REFERENCES patients(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ── Clinic sessions = visits (not HTTP sessions) ───────────────────────────
-- Note: table named `clinic_visits` to avoid collision with clinic_sessions.

CREATE TABLE IF NOT EXISTS clinic_visits (
  id VARCHAR(32) NOT NULL PRIMARY KEY,
  clinic_id VARCHAR(32) NOT NULL,
  patient_id VARCHAR(32) NOT NULL,
  practitioner_id VARCHAR(32) NOT NULL,
  upload_filename_encrypted BLOB NULL,
  upload_mime VARCHAR(64) NULL,
  upload_size_bytes INT UNSIGNED NULL,
  report_text_encrypted LONGBLOB NULL,
  findings_encrypted LONGBLOB NULL,
  viz_job_id VARCHAR(64) NULL,
  viz_image_url VARCHAR(255) NULL,
  status ENUM('uploaded','ocring','extracting','ready','generating','complete','failed') NOT NULL DEFAULT 'uploaded',
  ocr_method ENUM('pdftotext','tesseract','none') NULL,
  error_message TEXT NULL,
  retain_until DATETIME NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  INDEX idx_visit_clinic (clinic_id, status, created_at),
  INDEX idx_visit_patient (patient_id, created_at),
  INDEX idx_visit_practitioner (practitioner_id, created_at),
  INDEX idx_visit_retention (retain_until),
  CONSTRAINT fk_visit_clinic FOREIGN KEY (clinic_id) REFERENCES clinics(id) ON DELETE RESTRICT,
  CONSTRAINT fk_visit_patient FOREIGN KEY (patient_id) REFERENCES patients(id) ON DELETE RESTRICT,
  CONSTRAINT fk_visit_practitioner FOREIGN KEY (practitioner_id) REFERENCES clinic_users(id) ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ── Audit log (6 year retention) ───────────────────────────────────────────
-- Partitioning by month is added separately (see migration 002).

CREATE TABLE IF NOT EXISTS clinic_audit_log (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  clinic_id VARCHAR(32) NULL,
  user_id VARCHAR(32) NULL,
  event VARCHAR(64) NOT NULL,
  resource_type VARCHAR(32) NULL,
  resource_id VARCHAR(32) NULL,
  action ENUM('read','create','update','delete','share','export','login','logout','failed_auth','admin') NOT NULL,
  ip_address VARBINARY(16) NULL,
  user_agent_hash VARCHAR(64) NULL,
  success TINYINT(1) NOT NULL DEFAULT 1,
  details_encrypted BLOB NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  INDEX idx_audit_clinic_created (clinic_id, created_at),
  INDEX idx_audit_user_created (user_id, created_at),
  INDEX idx_audit_event (event, created_at),
  INDEX idx_audit_resource (resource_type, resource_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ── EMR connections (OAuth tokens, per-practitioner per-vendor) ────────────

CREATE TABLE IF NOT EXISTS emr_connections (
  id VARCHAR(32) NOT NULL PRIMARY KEY,
  clinic_id VARCHAR(32) NOT NULL,
  practitioner_id VARCHAR(32) NOT NULL,
  vendor ENUM('jane','cliniko','fhir','cerbo') NOT NULL,
  access_token_encrypted BLOB NOT NULL,
  refresh_token_encrypted BLOB NOT NULL,
  expires_at DATETIME NOT NULL,
  scopes JSON NOT NULL,
  external_subdomain VARCHAR(128) NULL,
  connected_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  last_sync_at DATETIME NULL,
  status ENUM('active','expired','revoked') NOT NULL DEFAULT 'active',
  UNIQUE KEY uq_emr_practitioner (practitioner_id, vendor),
  INDEX idx_emr_clinic (clinic_id, vendor, status),
  INDEX idx_emr_refresh (expires_at, status),
  CONSTRAINT fk_emr_clinic FOREIGN KEY (clinic_id) REFERENCES clinics(id) ON DELETE CASCADE,
  CONSTRAINT fk_emr_practitioner FOREIGN KEY (practitioner_id) REFERENCES clinic_users(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ── Failed-login throttling ────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS clinic_login_attempts (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  email_lower VARCHAR(255) NOT NULL,
  ip_address VARBINARY(16) NULL,
  success TINYINT(1) NOT NULL DEFAULT 0,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  INDEX idx_attempt_email (email_lower, created_at),
  INDEX idx_attempt_ip (ip_address, created_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
