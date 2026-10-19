-- ============================================================================
-- Module 7: Licences, Seats, Devices & Sessions
-- Deliverables: Subscription licences, seat allocation, registered devices,
--               session limits, login history, and session revocation audit
-- Compliance: Rule Groups 1, 2, 4, 9
-- ============================================================================

USE talentra_db;

-- 1. Subscription Licence Record (Rule Group 9)
CREATE TABLE IF NOT EXISTS subscription_licence (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    uuid CHAR(36) NOT NULL DEFAULT (UUID()),
    organisation_id BIGINT UNSIGNED NOT NULL,
    licence_key VARCHAR(100) NOT NULL,
    licence_tier_code VARCHAR(50) NOT NULL DEFAULT 'ENTERPRISE_PRO', -- 'STANDARD', 'PROFESSIONAL', 'ENTERPRISE_PRO'
    max_users INT UNSIGNED NOT NULL DEFAULT 5,
    max_devices_per_user INT UNSIGNED NOT NULL DEFAULT 2,
    valid_from_date DATE NOT NULL,
    valid_to_date DATE NOT NULL,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    created_by BIGINT UNSIGNED NULL,
    updated_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6),
    updated_by BIGINT UNSIGNED NULL,
    deleted_at DATETIME(6) NULL,
    CONSTRAINT pk_subscription_licence PRIMARY KEY (id),
    CONSTRAINT uq_subscription_licence_uuid UNIQUE (uuid),
    CONSTRAINT uq_subscription_licence_key UNIQUE (licence_key),
    CONSTRAINT fk_sl_organisation_id FOREIGN KEY (organisation_id) REFERENCES organisation (id) ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT chk_sl_max_users CHECK (max_users > 0),
    CONSTRAINT chk_sl_max_devices CHECK (max_devices_per_user > 0),
    CONSTRAINT chk_sl_validity CHECK (valid_to_date >= valid_from_date),
    INDEX idx_sl_organisation_id (organisation_id, is_active)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;


-- 2. Licence Seat Allocation to Users
CREATE TABLE IF NOT EXISTS licence_seat_allocation (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    uuid CHAR(36) NOT NULL DEFAULT (UUID()),
    subscription_licence_id BIGINT UNSIGNED NOT NULL,
    app_user_id BIGINT UNSIGNED NOT NULL,
    allocated_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    allocated_by BIGINT UNSIGNED NULL,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    created_by BIGINT UNSIGNED NULL,
    updated_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6),
    updated_by BIGINT UNSIGNED NULL,
    CONSTRAINT pk_licence_seat_allocation PRIMARY KEY (id),
    CONSTRAINT uq_licence_seat_allocation_uuid UNIQUE (uuid),
    CONSTRAINT uq_licence_user UNIQUE (subscription_licence_id, app_user_id),
    CONSTRAINT fk_lsa_licence_id FOREIGN KEY (subscription_licence_id) REFERENCES subscription_licence (id) ON UPDATE CASCADE ON DELETE CASCADE,
    CONSTRAINT fk_lsa_user_id FOREIGN KEY (app_user_id) REFERENCES app_user (id) ON UPDATE CASCADE ON DELETE CASCADE,
    INDEX idx_lsa_user_id (app_user_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;


-- 3. Registered Devices per User (Hardware Binding)
CREATE TABLE IF NOT EXISTS user_device (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    uuid CHAR(36) NOT NULL DEFAULT (UUID()),
    app_user_id BIGINT UNSIGNED NOT NULL,
    device_fingerprint_hash VARCHAR(128) NOT NULL,
    device_name VARCHAR(100) NOT NULL,
    device_type_code VARCHAR(50) NOT NULL, -- 'DESKTOP_MAC', 'DESKTOP_WINDOWS', 'MOBILE_IOS', 'MOBILE_ANDROID'
    operating_system VARCHAR(100) NOT NULL,
    browser_name VARCHAR(100) NULL,
    is_trusted BOOLEAN NOT NULL DEFAULT TRUE,
    is_revoked BOOLEAN NOT NULL DEFAULT FALSE,
    first_seen_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    last_seen_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6),
    created_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    created_by BIGINT UNSIGNED NULL,
    updated_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6),
    updated_by BIGINT UNSIGNED NULL,
    CONSTRAINT pk_user_device PRIMARY KEY (id),
    CONSTRAINT uq_user_device_uuid UNIQUE (uuid),
    CONSTRAINT uq_user_device_fingerprint UNIQUE (app_user_id, device_fingerprint_hash),
    CONSTRAINT fk_ud_user_id FOREIGN KEY (app_user_id) REFERENCES app_user (id) ON UPDATE CASCADE ON DELETE CASCADE,
    INDEX idx_user_device_user (app_user_id, is_revoked)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;


-- 4. Active Sessions Tracking (Rule Group 9)
CREATE TABLE IF NOT EXISTS user_session (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    uuid CHAR(36) NOT NULL DEFAULT (UUID()),
    app_user_id BIGINT UNSIGNED NOT NULL,
    user_device_id BIGINT UNSIGNED NOT NULL,
    session_token_hash VARCHAR(128) NOT NULL,
    ip_address VARCHAR(45) NOT NULL,
    user_agent_string VARCHAR(255) NULL,
    session_start_time DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    last_activity_time DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    session_end_time DATETIME(6) NULL,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    session_end_reason_code VARCHAR(50) NULL, -- 'LOGOUT', 'EXPIRED_INACTIVITY', 'REVOKED_BY_ADMIN', 'DEVICE_LIMIT_EXCEEDED'
    CONSTRAINT pk_user_session PRIMARY KEY (id),
    CONSTRAINT uq_user_session_uuid UNIQUE (uuid),
    CONSTRAINT uq_user_session_token UNIQUE (session_token_hash),
    CONSTRAINT fk_us_user_id FOREIGN KEY (app_user_id) REFERENCES app_user (id) ON UPDATE CASCADE ON DELETE CASCADE,
    CONSTRAINT fk_us_device_id FOREIGN KEY (user_device_id) REFERENCES user_device (id) ON UPDATE CASCADE ON DELETE CASCADE,
    CONSTRAINT chk_us_times CHECK (session_end_time IS NULL OR session_end_time >= session_start_time),
    INDEX idx_user_session_active (app_user_id, is_active),
    INDEX idx_user_session_last_activity (last_activity_time)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;


-- 5. Login Attempt History (Security Audit & Rate-Limiting)
CREATE TABLE IF NOT EXISTS login_attempt_history (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    email_address VARCHAR(254) NOT NULL,
    app_user_id BIGINT UNSIGNED NULL,
    ip_address VARCHAR(45) NOT NULL,
    user_agent_string VARCHAR(255) NULL,
    is_successful BOOLEAN NOT NULL,
    failure_reason_code VARCHAR(50) NULL, -- 'INVALID_CREDENTIALS', 'ACCOUNT_LOCKED', 'DEVICE_LIMIT_REACHED'
    attempted_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    CONSTRAINT pk_login_attempt_history PRIMARY KEY (id),
    CONSTRAINT fk_lah_user_id FOREIGN KEY (app_user_id) REFERENCES app_user (id) ON UPDATE CASCADE ON DELETE SET NULL,
    INDEX idx_lah_email_time (email_address, attempted_at),
    INDEX idx_lah_ip_time (ip_address, attempted_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;


-- 6. Auditable Session & Device Revocation Events (Rule Group 9)
CREATE TABLE IF NOT EXISTS session_revocation_event (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    uuid CHAR(36) NOT NULL DEFAULT (UUID()),
    user_session_id BIGINT UNSIGNED NOT NULL,
    revoked_by_user_id BIGINT UNSIGNED NOT NULL,
    revocation_reason VARCHAR(255) NOT NULL,
    revoked_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    CONSTRAINT pk_session_revocation_event PRIMARY KEY (id),
    CONSTRAINT uq_session_revocation_event_uuid UNIQUE (uuid),
    CONSTRAINT fk_sre_session_id FOREIGN KEY (user_session_id) REFERENCES user_session (id) ON UPDATE CASCADE ON DELETE CASCADE,
    CONSTRAINT fk_sre_revoker_id FOREIGN KEY (revoked_by_user_id) REFERENCES app_user (id) ON UPDATE CASCADE ON DELETE RESTRICT,
    INDEX idx_sre_session_id (user_session_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

