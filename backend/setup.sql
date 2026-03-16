-- Resolara backend schema
-- Run once: mysql -u DAUSER_resolara_user -p DAUSER_resolara < setup.sql
-- Then delete or move this file off the server.

CREATE TABLE IF NOT EXISTS activation_codes (
    code             VARCHAR(64)  PRIMARY KEY,
    description      VARCHAR(255),
    max_activations  INT          DEFAULT 1,
    activation_count INT          DEFAULT 0,
    created_at       DATETIME     DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS devices (
    id              INT AUTO_INCREMENT PRIMARY KEY,
    activation_code VARCHAR(64)  NOT NULL,
    token           VARCHAR(128) NOT NULL UNIQUE,
    created_at      DATETIME     DEFAULT CURRENT_TIMESTAMP,
    last_seen       DATETIME,
    INDEX idx_token (token)
);

CREATE TABLE IF NOT EXISTS jobs (
    id            CHAR(36)     PRIMARY KEY,
    device_token  VARCHAR(128) NOT NULL,
    status        ENUM('pending','processing','completed','failed') DEFAULT 'pending',
    image_path    VARCHAR(255),
    result_json   MEDIUMTEXT,
    error_message TEXT,
    created_at    DATETIME     DEFAULT CURRENT_TIMESTAMP,
    updated_at    DATETIME     DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    INDEX idx_device (device_token),
    INDEX idx_status (status)
);

CREATE TABLE IF NOT EXISTS visualizations (
    id              CHAR(36)     PRIMARY KEY,
    device_token    VARCHAR(128) NOT NULL,
    status          ENUM('pending','processing','completed','failed') DEFAULT 'pending',
    findings_json   TEXT,
    image_filename  VARCHAR(255),
    error_message   TEXT,
    created_at      DATETIME     DEFAULT CURRENT_TIMESTAMP,
    updated_at      DATETIME     DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    INDEX idx_device (device_token)
);

CREATE TABLE IF NOT EXISTS activation_attempts (
    id           INT AUTO_INCREMENT PRIMARY KEY,
    ip           VARCHAR(45)  NOT NULL,
    attempted_at DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_ip_time (ip, attempted_at)
);

-- Seed demo activation codes
INSERT IGNORE INTO activation_codes (code, description, max_activations) VALUES
    ('RESOLARA-DEMO-001', 'Demo activation 1', 10),
    ('RESOLARA-DEMO-002', 'Demo activation 2', 10),
    ('RESOLARA-DEV-001',  'Developer device',  99);
