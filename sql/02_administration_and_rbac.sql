-- ============================================================================
-- Module 2: Administration, Identity & RBAC
-- Deliverables: Users, credentials, roles, permissions, consents, audit, blocking
-- Compliance: Rule Groups 1, 2, 3, 4, 6, 9
-- ============================================================================

USE talentra_db;

-- 1. Central Application User Account
CREATE TABLE IF NOT EXISTS app_user (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    uuid CHAR(36) NOT NULL DEFAULT (UUID()),
    email_address VARCHAR(254) NOT NULL,
    country_dial_code VARCHAR(5) NOT NULL,
    national_phone_number VARCHAR(15) NOT NULL,
    user_status_code VARCHAR(50) NOT NULL DEFAULT 'ACTIVE', -- 'PENDING_VERIFICATION', 'ACTIVE', 'SUSPENDED', 'DEACTIVATED'
    is_email_verified BOOLEAN NOT NULL DEFAULT FALSE,
    is_phone_verified BOOLEAN NOT NULL DEFAULT FALSE,
    preferred_language_code CHAR(2) NOT NULL DEFAULT 'en',
    failed_login_count INT UNSIGNED NOT NULL DEFAULT 0,
    locked_until DATETIME(6) NULL,
    last_login_at DATETIME(6) NULL,
    created_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    created_by BIGINT UNSIGNED NULL,
    updated_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6),
    updated_by BIGINT UNSIGNED NULL,
    deleted_at DATETIME(6) NULL,
    CONSTRAINT pk_app_user PRIMARY KEY (id),
    CONSTRAINT uq_app_user_uuid UNIQUE (uuid),
    CONSTRAINT uq_app_user_email UNIQUE (email_address),
    CONSTRAINT chk_app_user_email_lower CHECK (email_address = LOWER(email_address)),
    INDEX idx_app_user_status (user_status_code),
    INDEX idx_app_user_phone (country_dial_code, national_phone_number)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;


-- 2. Sensitive User Credential
CREATE TABLE IF NOT EXISTS user_credential (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    uuid CHAR(36) NOT NULL DEFAULT (UUID()),
    app_user_id BIGINT UNSIGNED NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    password_salt VARCHAR(128) NOT NULL,
    hash_algorithm VARCHAR(50) NOT NULL DEFAULT 'ARGON2ID',
    password_changed_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    is_temporary_password BOOLEAN NOT NULL DEFAULT FALSE,
    must_change_password BOOLEAN NOT NULL DEFAULT FALSE,
    created_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    created_by BIGINT UNSIGNED NULL,
    updated_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6),
    updated_by BIGINT UNSIGNED NULL,
    CONSTRAINT pk_user_credential PRIMARY KEY (id),
    CONSTRAINT uq_user_credential_uuid UNIQUE (uuid),
    CONSTRAINT uq_user_credential_app_user_id UNIQUE (app_user_id),
    CONSTRAINT fk_user_credential_app_user_id FOREIGN KEY (app_user_id) REFERENCES app_user (id) ON UPDATE CASCADE ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- 3. System Role Definition
CREATE TABLE IF NOT EXISTS role_definition (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    uuid CHAR(36) NOT NULL DEFAULT (UUID()),
    role_code VARCHAR(50) NOT NULL,
    role_name VARCHAR(100) NOT NULL,
    role_description VARCHAR(255) NULL,
    is_system_role BOOLEAN NOT NULL DEFAULT TRUE,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    created_by BIGINT UNSIGNED NULL,
    updated_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6),
    updated_by BIGINT UNSIGNED NULL,
    CONSTRAINT pk_role_definition PRIMARY KEY (id),
    CONSTRAINT uq_role_definition_uuid UNIQUE (uuid),
    CONSTRAINT uq_role_definition_code UNIQUE (role_code)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- 4. Granular Application Permission
CREATE TABLE IF NOT EXISTS app_permission (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    uuid CHAR(36) NOT NULL DEFAULT (UUID()),
    permission_code VARCHAR(100) NOT NULL,
    permission_name VARCHAR(150) NOT NULL,
    module_category VARCHAR(50) NOT NULL,
    permission_description VARCHAR(255) NULL,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    created_by BIGINT UNSIGNED NULL,
    updated_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6),
    updated_by BIGINT UNSIGNED NULL,
    CONSTRAINT pk_app_permission PRIMARY KEY (id),
    CONSTRAINT uq_app_permission_uuid UNIQUE (uuid),
    CONSTRAINT uq_app_permission_code UNIQUE (permission_code)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- 5. Role to Permission Mapping
CREATE TABLE IF NOT EXISTS role_permission_mapping (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    role_definition_id BIGINT UNSIGNED NOT NULL,
    app_permission_id BIGINT UNSIGNED NOT NULL,
    created_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    created_by BIGINT UNSIGNED NULL,
    CONSTRAINT pk_role_permission_mapping PRIMARY KEY (id),
    CONSTRAINT uq_role_permission UNIQUE (role_definition_id, app_permission_id),
    CONSTRAINT fk_rpm_role_definition_id FOREIGN KEY (role_definition_id) REFERENCES role_definition (id) ON UPDATE CASCADE ON DELETE CASCADE,
    CONSTRAINT fk_rpm_app_permission_id FOREIGN KEY (app_permission_id) REFERENCES app_permission (id) ON UPDATE CASCADE ON DELETE CASCADE,
    INDEX idx_rpm_permission_id (app_permission_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;


-- 6. User Role Assignment
CREATE TABLE IF NOT EXISTS user_role_assignment (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    app_user_id BIGINT UNSIGNED NOT NULL,
    role_definition_id BIGINT UNSIGNED NOT NULL,
    assigned_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    assigned_by BIGINT UNSIGNED NULL,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    CONSTRAINT pk_user_role_assignment PRIMARY KEY (id),
    CONSTRAINT uq_user_role UNIQUE (app_user_id, role_definition_id),
    CONSTRAINT fk_ura_app_user_id FOREIGN KEY (app_user_id) REFERENCES app_user (id) ON UPDATE CASCADE ON DELETE CASCADE,
    CONSTRAINT fk_ura_role_definition_id FOREIGN KEY (role_definition_id) REFERENCES role_definition (id) ON UPDATE CASCADE ON DELETE RESTRICT,
    INDEX idx_ura_role_definition_id (role_definition_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;


-- 7. User Consent Records (GDPR, DPDP Compliance)
CREATE TABLE IF NOT EXISTS user_consent_record (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    uuid CHAR(36) NOT NULL DEFAULT (UUID()),
    app_user_id BIGINT UNSIGNED NOT NULL,
    consent_purpose_code VARCHAR(50) NOT NULL, -- 'TERMS_OF_SERVICE', 'PRIVACY_POLICY', 'MARKETING_PROMOTIONS', 'DATA_SHARING_RECRUITERS'
    consent_version VARCHAR(20) NOT NULL,
    is_granted BOOLEAN NOT NULL,
    ip_address VARCHAR(45) NOT NULL,
    user_agent_string VARCHAR(255) NULL,
    granted_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    revoked_at DATETIME(6) NULL,
    created_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    created_by BIGINT UNSIGNED NULL,
    updated_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6),
    updated_by BIGINT UNSIGNED NULL,
    CONSTRAINT pk_user_consent_record PRIMARY KEY (id),
    CONSTRAINT uq_user_consent_record_uuid UNIQUE (uuid),
    CONSTRAINT fk_user_consent_app_user_id FOREIGN KEY (app_user_id) REFERENCES app_user (id) ON UPDATE CASCADE ON DELETE CASCADE,
    INDEX idx_user_consent_lookup (app_user_id, consent_purpose_code)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;


-- 8. Immutable Append-Only Audit Log (Rule Group 4, 6)
CREATE TABLE IF NOT EXISTS audit_log (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    uuid CHAR(36) NOT NULL DEFAULT (UUID()),
    actor_user_id BIGINT UNSIGNED NULL,
    impersonator_user_id BIGINT UNSIGNED NULL,
    action_type VARCHAR(100) NOT NULL, -- E.g. 'USER_LOGIN', 'PROFILE_VIEW', 'CANDIDATE_BLOCKED', 'SECURITY_BREACH'
    target_entity_name VARCHAR(100) NOT NULL,
    target_entity_id BIGINT UNSIGNED NOT NULL,
    ip_address VARCHAR(45) NOT NULL,
    user_agent_string VARCHAR(255) NULL,
    pre_change_state JSON NULL,
    post_change_state JSON NULL,
    action_timestamp DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    CONSTRAINT pk_audit_log PRIMARY KEY (id),
    CONSTRAINT uq_audit_log_uuid UNIQUE (uuid),
    INDEX idx_audit_log_actor (actor_user_id, action_timestamp),
    INDEX idx_audit_log_entity (target_entity_name, target_entity_id),
    INDEX idx_audit_log_timestamp (action_timestamp)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;


-- 9. Privacy Blocking Registry (Candidate Blocking Employers / Recruiters / Consultants)
CREATE TABLE IF NOT EXISTS privacy_block_entry (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    uuid CHAR(36) NOT NULL DEFAULT (UUID()),
    blocker_candidate_user_id BIGINT UNSIGNED NOT NULL,
    blocked_entity_type VARCHAR(50) NOT NULL, -- 'ORGANISATION', 'RECRUITER_USER', 'CONSULTANT_USER'
    blocked_target_id BIGINT UNSIGNED NOT NULL, -- organisation.id or app_user.id
    block_reason VARCHAR(255) NULL,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    created_by BIGINT UNSIGNED NULL,
    updated_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6),
    updated_by BIGINT UNSIGNED NULL,
    deleted_at DATETIME(6) NULL,
    CONSTRAINT pk_privacy_block_entry PRIMARY KEY (id),
    CONSTRAINT uq_privacy_block_entry_uuid UNIQUE (uuid),
    CONSTRAINT uq_privacy_block_rule UNIQUE (blocker_candidate_user_id, blocked_entity_type, blocked_target_id),
    CONSTRAINT fk_pbe_blocker_id FOREIGN KEY (blocker_candidate_user_id) REFERENCES app_user (id) ON UPDATE CASCADE ON DELETE CASCADE,
    INDEX idx_privacy_block_search (blocked_entity_type, blocked_target_id, is_active)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

