-- ============================================================================
-- Module 3: Organisation, Accounts & Recruiter Mapping
-- Deliverables: Companies, locations, tax IDs, verification, recruiter mapping
-- Compliance: Rule Groups 1, 2, 3, 4, 6
-- ============================================================================

USE talentra_db;

-- 1. Corporate Organisation Master Record
CREATE TABLE IF NOT EXISTS organisation (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    uuid CHAR(36) NOT NULL DEFAULT (UUID()),
    parent_organisation_id BIGINT UNSIGNED NULL,
    legal_name VARCHAR(200) NOT NULL,
    trade_name VARCHAR(150) NOT NULL,
    organisation_type_code VARCHAR(50) NOT NULL, -- 'ENTERPRISE', 'SME', 'STAFFING_AGENCY', 'INSTITUTE_COLLEGE', 'CONSULTING_FIRM'
    industry_sector_id BIGINT UNSIGNED NOT NULL,
    company_website_url VARCHAR(255) NULL,
    primary_email_address VARCHAR(254) NOT NULL,
    verification_status_code VARCHAR(50) NOT NULL DEFAULT 'PENDING', -- 'PENDING', 'PROVISIONAL', 'VERIFIED', 'REJECTED', 'SUSPENDED'
    account_status_code VARCHAR(50) NOT NULL DEFAULT 'ACTIVE', -- 'ACTIVE', 'OVERDUE', 'SUSPENDED', 'CLOSED'
    created_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    created_by BIGINT UNSIGNED NULL,
    updated_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6),
    updated_by BIGINT UNSIGNED NULL,
    deleted_at DATETIME(6) NULL,
    CONSTRAINT pk_organisation PRIMARY KEY (id),
    CONSTRAINT uq_organisation_uuid UNIQUE (uuid),
    CONSTRAINT uq_organisation_legal_name UNIQUE (legal_name),
    CONSTRAINT fk_organisation_parent_id FOREIGN KEY (parent_organisation_id) REFERENCES organisation (id) ON UPDATE CASCADE ON DELETE SET NULL,
    CONSTRAINT fk_organisation_industry_id FOREIGN KEY (industry_sector_id) REFERENCES industry_sector (id) ON UPDATE CASCADE ON DELETE RESTRICT,
    INDEX idx_organisation_parent (parent_organisation_id),
    INDEX idx_organisation_status (verification_status_code, account_status_code)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;


-- 2. Physical Corporate Office Locations
CREATE TABLE IF NOT EXISTS office_location (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    uuid CHAR(36) NOT NULL DEFAULT (UUID()),
    organisation_id BIGINT UNSIGNED NOT NULL,
    location_label VARCHAR(100) NOT NULL, -- 'HEADQUARTERS', 'REGIONAL_HUB', 'BRANCH_OFFICE'
    city_id BIGINT UNSIGNED NOT NULL,
    street_address_line1 VARCHAR(200) NOT NULL,
    street_address_line2 VARCHAR(200) NULL,
    postal_code VARCHAR(20) NOT NULL,
    latitude DECIMAL(10, 8) NULL,
    longitude DECIMAL(11, 8) NULL,
    is_headquarters BOOLEAN NOT NULL DEFAULT FALSE,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    created_by BIGINT UNSIGNED NULL,
    updated_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6),
    updated_by BIGINT UNSIGNED NULL,
    deleted_at DATETIME(6) NULL,
    CONSTRAINT pk_office_location PRIMARY KEY (id),
    CONSTRAINT uq_office_location_uuid UNIQUE (uuid),
    CONSTRAINT fk_office_location_org_id FOREIGN KEY (organisation_id) REFERENCES organisation (id) ON UPDATE CASCADE ON DELETE CASCADE,
    CONSTRAINT fk_office_location_city_id FOREIGN KEY (city_id) REFERENCES city (id) ON UPDATE CASCADE ON DELETE RESTRICT,
    INDEX idx_office_location_org (organisation_id),
    INDEX idx_office_location_city (city_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;


-- 3. Corporate Registration & Tax Verification Identifiers
CREATE TABLE IF NOT EXISTS organisation_verification (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    uuid CHAR(36) NOT NULL DEFAULT (UUID()),
    organisation_id BIGINT UNSIGNED NOT NULL,
    identifier_type_code VARCHAR(50) NOT NULL, -- 'CIN', 'GSTIN', 'EIN', 'VAT', 'PAN'
    identifier_value_masked VARCHAR(50) NOT NULL,
    identifier_hash VARCHAR(128) NOT NULL, -- Salted hash for unique collision checks
    country_id BIGINT UNSIGNED NOT NULL,
    verification_status_code VARCHAR(50) NOT NULL DEFAULT 'SUBMITTED', -- 'SUBMITTED', 'IN_REVIEW', 'VERIFIED', 'FAILED'
    verification_reference_id VARCHAR(100) NULL,
    verified_at DATETIME(6) NULL,
    created_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    created_by BIGINT UNSIGNED NULL,
    updated_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6),
    updated_by BIGINT UNSIGNED NULL,
    CONSTRAINT pk_organisation_verification PRIMARY KEY (id),
    CONSTRAINT uq_organisation_verification_uuid UNIQUE (uuid),
    CONSTRAINT uq_org_verification_hash UNIQUE (identifier_type_code, identifier_hash),
    CONSTRAINT fk_org_verif_organisation_id FOREIGN KEY (organisation_id) REFERENCES organisation (id) ON UPDATE CASCADE ON DELETE CASCADE,
    CONSTRAINT fk_org_verif_country_id FOREIGN KEY (country_id) REFERENCES country (id) ON UPDATE CASCADE ON DELETE RESTRICT,
    INDEX idx_org_verif_org_id (organisation_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;


-- 4. Account Administrators (Multi-Admin Corporate Ownership)
CREATE TABLE IF NOT EXISTS account_administrator (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    uuid CHAR(36) NOT NULL DEFAULT (UUID()),
    organisation_id BIGINT UNSIGNED NOT NULL,
    app_user_id BIGINT UNSIGNED NOT NULL,
    administrator_tier_code VARCHAR(50) NOT NULL DEFAULT 'PRIMARY_ADMIN', -- 'PRIMARY_ADMIN', 'BILLING_ADMIN', 'HR_ADMIN'
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    created_by BIGINT UNSIGNED NULL,
    updated_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6),
    updated_by BIGINT UNSIGNED NULL,
    CONSTRAINT pk_account_administrator PRIMARY KEY (id),
    CONSTRAINT uq_account_admin UNIQUE (organisation_id, app_user_id),
    CONSTRAINT fk_account_admin_org_id FOREIGN KEY (organisation_id) REFERENCES organisation (id) ON UPDATE CASCADE ON DELETE CASCADE,
    CONSTRAINT fk_account_admin_user_id FOREIGN KEY (app_user_id) REFERENCES app_user (id) ON UPDATE CASCADE ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- 5. Effective-Dated Recruiter Mapping (Rule Group 2 & Section 3)
-- "A recruiter may only see and act on job requirements assigned to their own company"
CREATE TABLE IF NOT EXISTS recruiter_assignment (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    uuid CHAR(36) NOT NULL DEFAULT (UUID()),
    organisation_id BIGINT UNSIGNED NOT NULL,
    recruiter_user_id BIGINT UNSIGNED NOT NULL,
    assignment_role_code VARCHAR(50) NOT NULL DEFAULT 'INTERNAL_RECRUITER', -- 'INTERNAL_RECRUITER', 'LEAD_TALENT_PARTNER'
    effective_from_date DATE NOT NULL,
    effective_to_date DATE NULL,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    created_by BIGINT UNSIGNED NULL,
    updated_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6),
    updated_by BIGINT UNSIGNED NULL,
    CONSTRAINT pk_recruiter_assignment PRIMARY KEY (id),
    CONSTRAINT uq_recruiter_assignment_uuid UNIQUE (uuid),
    CONSTRAINT fk_recruiter_assign_org_id FOREIGN KEY (organisation_id) REFERENCES organisation (id) ON UPDATE CASCADE ON DELETE CASCADE,
    CONSTRAINT fk_recruiter_assign_user_id FOREIGN KEY (recruiter_user_id) REFERENCES app_user (id) ON UPDATE CASCADE ON DELETE CASCADE,
    CONSTRAINT chk_recruiter_dates CHECK (effective_to_date IS NULL OR effective_to_date >= effective_from_date),
    INDEX idx_recruiter_assignment_search (recruiter_user_id, organisation_id, is_active)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

