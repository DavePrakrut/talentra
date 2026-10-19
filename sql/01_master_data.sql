-- ============================================================================
-- Module 1: Master Data & Taxonomies
-- Deliverables: Canonical reference catalogs, multilingual UI translations
-- Compliance: Rule Groups 1, 2, 3, 4, 7
-- ============================================================================

USE talentra_db;

-- 1. Country Master Data
CREATE TABLE IF NOT EXISTS country (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    uuid CHAR(36) NOT NULL DEFAULT (UUID()),
    iso_alpha2_code CHAR(2) NOT NULL,
    iso_alpha3_code CHAR(3) NOT NULL,
    country_name VARCHAR(150) NOT NULL,
    country_dial_code VARCHAR(5) NOT NULL,
    default_currency_code CHAR(3) NOT NULL,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    display_order INT NOT NULL DEFAULT 0,
    created_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    created_by BIGINT UNSIGNED NULL,
    updated_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6),
    updated_by BIGINT UNSIGNED NULL,
    deleted_at DATETIME(6) NULL,
    CONSTRAINT pk_country PRIMARY KEY (id),
    CONSTRAINT uq_country_uuid UNIQUE (uuid),
    CONSTRAINT uq_country_iso_alpha2_code UNIQUE (iso_alpha2_code),
    CONSTRAINT uq_country_iso_alpha3_code UNIQUE (iso_alpha3_code),
    INDEX idx_country_name (country_name)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;


-- 2. State / Province Master Data
CREATE TABLE IF NOT EXISTS state_province (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    uuid CHAR(36) NOT NULL DEFAULT (UUID()),
    country_id BIGINT UNSIGNED NOT NULL,
    state_code VARCHAR(10) NOT NULL,
    state_name VARCHAR(150) NOT NULL,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    display_order INT NOT NULL DEFAULT 0,
    created_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    created_by BIGINT UNSIGNED NULL,
    updated_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6),
    updated_by BIGINT UNSIGNED NULL,
    deleted_at DATETIME(6) NULL,
    CONSTRAINT pk_state_province PRIMARY KEY (id),
    CONSTRAINT uq_state_province_uuid UNIQUE (uuid),
    CONSTRAINT uq_state_province_country_code UNIQUE (country_id, state_code),
    CONSTRAINT fk_state_province_country_id FOREIGN KEY (country_id) REFERENCES country (id) ON UPDATE CASCADE ON DELETE RESTRICT,
    INDEX idx_state_province_country_id (country_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;


-- 3. City Master Data
CREATE TABLE IF NOT EXISTS city (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    uuid CHAR(36) NOT NULL DEFAULT (UUID()),
    state_province_id BIGINT UNSIGNED NOT NULL,
    city_name VARCHAR(150) NOT NULL,
    latitude DECIMAL(10, 8) NULL,
    longitude DECIMAL(11, 8) NULL,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    display_order INT NOT NULL DEFAULT 0,
    created_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    created_by BIGINT UNSIGNED NULL,
    updated_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6),
    updated_by BIGINT UNSIGNED NULL,
    deleted_at DATETIME(6) NULL,
    CONSTRAINT pk_city PRIMARY KEY (id),
    CONSTRAINT uq_city_uuid UNIQUE (uuid),
    CONSTRAINT fk_city_state_province_id FOREIGN KEY (state_province_id) REFERENCES state_province (id) ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT chk_city_coordinates CHECK (
        (latitude IS NULL AND longitude IS NULL) OR 
        (latitude BETWEEN -90.00000000 AND 90.00000000 AND longitude BETWEEN -180.00000000 AND 180.00000000)
    ),
    INDEX idx_city_state_province_id (state_province_id),
    INDEX idx_city_city_name (city_name)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;


-- 4. Spoken / Written Language Master Data
CREATE TABLE IF NOT EXISTS spoken_language (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    uuid CHAR(36) NOT NULL DEFAULT (UUID()),
    iso_639_1_code CHAR(2) NOT NULL,
    iso_639_2_code CHAR(3) NOT NULL,
    language_name VARCHAR(100) NOT NULL,
    native_script_name VARCHAR(150) NOT NULL,
    is_ui_supported BOOLEAN NOT NULL DEFAULT FALSE,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    created_by BIGINT UNSIGNED NULL,
    updated_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6),
    updated_by BIGINT UNSIGNED NULL,
    deleted_at DATETIME(6) NULL,
    CONSTRAINT pk_spoken_language PRIMARY KEY (id),
    CONSTRAINT uq_spoken_language_uuid UNIQUE (uuid),
    CONSTRAINT uq_spoken_language_iso_code UNIQUE (iso_639_1_code)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- 5. Multilingual UI Translation String Catalog (Rule Group 7)
CREATE TABLE IF NOT EXISTS ui_translation (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    uuid CHAR(36) NOT NULL DEFAULT (UUID()),
    translation_key VARCHAR(150) NOT NULL,
    language_code CHAR(2) NOT NULL,
    translated_text TEXT NOT NULL,
    fallback_text TEXT NOT NULL,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    created_by BIGINT UNSIGNED NULL,
    updated_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6),
    updated_by BIGINT UNSIGNED NULL,
    CONSTRAINT pk_ui_translation PRIMARY KEY (id),
    CONSTRAINT uq_ui_translation_uuid UNIQUE (uuid),
    CONSTRAINT uq_ui_translation_key_lang UNIQUE (translation_key, language_code),
    INDEX idx_ui_translation_key (translation_key)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;


-- 6. Hierarchical Skill Category
CREATE TABLE IF NOT EXISTS skill_category (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    uuid CHAR(36) NOT NULL DEFAULT (UUID()),
    parent_category_id BIGINT UNSIGNED NULL,
    category_code VARCHAR(50) NOT NULL,
    category_name VARCHAR(150) NOT NULL,
    category_description VARCHAR(255) NULL,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    display_order INT NOT NULL DEFAULT 0,
    created_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    created_by BIGINT UNSIGNED NULL,
    updated_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6),
    updated_by BIGINT UNSIGNED NULL,
    deleted_at DATETIME(6) NULL,
    CONSTRAINT pk_skill_category PRIMARY KEY (id),
    CONSTRAINT uq_skill_category_uuid UNIQUE (uuid),
    CONSTRAINT uq_skill_category_code UNIQUE (category_code),
    CONSTRAINT fk_skill_category_parent_id FOREIGN KEY (parent_category_id) REFERENCES skill_category (id) ON UPDATE CASCADE ON DELETE SET NULL,
    INDEX idx_skill_category_parent_id (parent_category_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;


-- 7. Skill Taxonomy
CREATE TABLE IF NOT EXISTS skill (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    uuid CHAR(36) NOT NULL DEFAULT (UUID()),
    skill_category_id BIGINT UNSIGNED NOT NULL,
    skill_code VARCHAR(50) NOT NULL,
    skill_name VARCHAR(150) NOT NULL,
    skill_description VARCHAR(255) NULL,
    is_trending BOOLEAN NOT NULL DEFAULT FALSE,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    display_order INT NOT NULL DEFAULT 0,
    created_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    created_by BIGINT UNSIGNED NULL,
    updated_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6),
    updated_by BIGINT UNSIGNED NULL,
    deleted_at DATETIME(6) NULL,
    CONSTRAINT pk_skill PRIMARY KEY (id),
    CONSTRAINT uq_skill_uuid UNIQUE (uuid),
    CONSTRAINT uq_skill_code UNIQUE (skill_code),
    CONSTRAINT fk_skill_category_id FOREIGN KEY (skill_category_id) REFERENCES skill_category (id) ON UPDATE CASCADE ON DELETE RESTRICT,
    INDEX idx_skill_category_id (skill_category_id),
    INDEX idx_skill_name (skill_name)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;


-- 8. Educational Qualification Master Data
CREATE TABLE IF NOT EXISTS educational_qualification (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    uuid CHAR(36) NOT NULL DEFAULT (UUID()),
    qualification_code VARCHAR(50) NOT NULL,
    qualification_name VARCHAR(150) NOT NULL,
    qualification_level VARCHAR(50) NOT NULL, -- E.g. 'SECONDARY', 'BACHELORS', 'MASTERS', 'DOCTORATE'
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    display_order INT NOT NULL DEFAULT 0,
    created_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    created_by BIGINT UNSIGNED NULL,
    updated_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6),
    updated_by BIGINT UNSIGNED NULL,
    deleted_at DATETIME(6) NULL,
    CONSTRAINT pk_educational_qualification PRIMARY KEY (id),
    CONSTRAINT uq_educational_qualification_uuid UNIQUE (uuid),
    CONSTRAINT uq_educational_qualification_code UNIQUE (qualification_code)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- 9. Industry Sector Master Data
CREATE TABLE IF NOT EXISTS industry_sector (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    uuid CHAR(36) NOT NULL DEFAULT (UUID()),
    industry_code VARCHAR(50) NOT NULL,
    industry_name VARCHAR(150) NOT NULL,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    display_order INT NOT NULL DEFAULT 0,
    created_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    created_by BIGINT UNSIGNED NULL,
    updated_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6),
    updated_by BIGINT UNSIGNED NULL,
    deleted_at DATETIME(6) NULL,
    CONSTRAINT pk_industry_sector PRIMARY KEY (id),
    CONSTRAINT uq_industry_sector_uuid UNIQUE (uuid),
    CONSTRAINT uq_industry_sector_code UNIQUE (industry_code)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- 10. Job Functional Role Master Data
CREATE TABLE IF NOT EXISTS job_role (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    uuid CHAR(36) NOT NULL DEFAULT (UUID()),
    industry_sector_id BIGINT UNSIGNED NOT NULL,
    role_code VARCHAR(50) NOT NULL,
    role_name VARCHAR(150) NOT NULL,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    display_order INT NOT NULL DEFAULT 0,
    created_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    created_by BIGINT UNSIGNED NULL,
    updated_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6),
    updated_by BIGINT UNSIGNED NULL,
    deleted_at DATETIME(6) NULL,
    CONSTRAINT pk_job_role PRIMARY KEY (id),
    CONSTRAINT uq_job_role_uuid UNIQUE (uuid),
    CONSTRAINT uq_job_role_code UNIQUE (role_code),
    CONSTRAINT fk_job_role_industry_id FOREIGN KEY (industry_sector_id) REFERENCES industry_sector (id) ON UPDATE CASCADE ON DELETE RESTRICT,
    INDEX idx_job_role_industry_id (industry_sector_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;


-- 11. Employment Type Lookup (Rule Group 3 Enumeration)
CREATE TABLE IF NOT EXISTS employment_type_lookup (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    lookup_code VARCHAR(50) NOT NULL,
    display_name VARCHAR(100) NOT NULL,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    sort_order INT NOT NULL DEFAULT 0,
    CONSTRAINT pk_employment_type_lookup PRIMARY KEY (id),
    CONSTRAINT uq_employment_type_code UNIQUE (lookup_code)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- 12. Work Mode Lookup (On-site, Hybrid, Remote)
CREATE TABLE IF NOT EXISTS work_mode_lookup (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    lookup_code VARCHAR(50) NOT NULL,
    display_name VARCHAR(100) NOT NULL,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    sort_order INT NOT NULL DEFAULT 0,
    CONSTRAINT pk_work_mode_lookup PRIMARY KEY (id),
    CONSTRAINT uq_work_mode_code UNIQUE (lookup_code)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- 13. Currency Code Lookup (ISO 4217)
CREATE TABLE IF NOT EXISTS currency_code_lookup (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    currency_code CHAR(3) NOT NULL,
    currency_name VARCHAR(100) NOT NULL,
    currency_symbol VARCHAR(10) NOT NULL,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    sort_order INT NOT NULL DEFAULT 0,
    CONSTRAINT pk_currency_code_lookup PRIMARY KEY (id),
    CONSTRAINT uq_currency_code_lookup UNIQUE (currency_code)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
