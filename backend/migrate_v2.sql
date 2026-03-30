-- v2 migration — run once on the live server
-- mysql -u DAUSER_resolara -p DAUSER_resolara < migrate_v2.sql

-- Add role column to devices (default 'practitioner' keeps existing rows valid)
ALTER TABLE devices
    ADD COLUMN IF NOT EXISTS role ENUM('practitioner','patient') NOT NULL DEFAULT 'practitioner';

-- Patient accounts
CREATE TABLE IF NOT EXISTS patient_users (
    id         CHAR(36)     PRIMARY KEY,
    email      VARCHAR(255) NOT NULL UNIQUE,
    created_at DATETIME     DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_email (email)
);

-- Magic link tokens (one-time use, 30-min expiry)
CREATE TABLE IF NOT EXISTS magic_link_tokens (
    id         CHAR(36)     PRIMARY KEY,
    user_id    CHAR(36)     NOT NULL,
    email      VARCHAR(255) NOT NULL,
    token      CHAR(64)     NOT NULL UNIQUE,
    created_at DATETIME     DEFAULT CURRENT_TIMESTAMP,
    expires_at DATETIME     NOT NULL,
    used_at    DATETIME     NULL,
    INDEX idx_token  (token),
    INDEX idx_email  (email),
    INDEX idx_expiry (expires_at),
    FOREIGN KEY (user_id) REFERENCES patient_users(id) ON DELETE CASCADE
);
