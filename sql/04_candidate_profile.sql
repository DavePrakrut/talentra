-- ============================================================================
-- Module 4: Candidate Profile Core & Lifecycle
-- Deliverables: Profile core, education, experience, skills, resumes, assessments,
--               projects, completion score, view history, activity log, referrals
-- Compliance: Rule Groups 1, 2, 3, 4, 5, 6
-- ============================================================================

USE talentra_db;

-- 1. Candidate Core Profile
CREATE TABLE IF NOT EXISTS candidate_profile (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    uuid CHAR(36) NOT NULL DEFAULT (UUID()),
    app_user_id BIGINT UNSIGNED NOT NULL,
    first_name VARCHAR(75) NOT NULL,
    last_name VARCHAR(75) NULL, -- Mononymic name support
    display_name VARCHAR(150) NOT NULL,
    date_of_birth DATE NULL,
    gender_code VARCHAR(20) NULL, -- 'MALE', 'FEMALE', 'NON_BINARY', 'PREFER_NOT_TO_SAY'
    current_city_id BIGINT UNSIGNED NULL,
    current_job_role_id BIGINT UNSIGNED NULL,
    total_experience_months INT UNSIGNED NOT NULL DEFAULT 0,
    current_salary DECIMAL(14, 2) NULL,
    expected_salary DECIMAL(14, 2) NULL,
    salary_currency_code CHAR(3) NOT NULL DEFAULT 'INR',
    salary_disclosure_status VARCHAR(50) NOT NULL DEFAULT 'DISCLOSED', -- 'DISCLOSED', 'UNDISCLOSED', 'NOT_APPLICABLE'
    notice_period_days INT UNSIGNED NOT NULL DEFAULT 30,
    professional_summary TEXT NULL,
    profile_completion_percentage DECIMAL(5, 2) NOT NULL DEFAULT 0.00,
    is_actively_looking BOOLEAN NOT NULL DEFAULT TRUE,
    created_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    created_by BIGINT UNSIGNED NULL,
    updated_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6),
    updated_by BIGINT UNSIGNED NULL,
    deleted_at DATETIME(6) NULL,
    CONSTRAINT pk_candidate_profile PRIMARY KEY (id),
    CONSTRAINT uq_candidate_profile_uuid UNIQUE (uuid),
    CONSTRAINT uq_candidate_app_user UNIQUE (app_user_id),
    CONSTRAINT fk_cp_app_user_id FOREIGN KEY (app_user_id) REFERENCES app_user (id) ON UPDATE CASCADE ON DELETE CASCADE,
    CONSTRAINT fk_cp_city_id FOREIGN KEY (current_city_id) REFERENCES city (id) ON UPDATE CASCADE ON DELETE SET NULL,
    CONSTRAINT fk_cp_job_role_id FOREIGN KEY (current_job_role_id) REFERENCES job_role (id) ON UPDATE CASCADE ON DELETE SET NULL,
    CONSTRAINT chk_cp_completion_pct CHECK (profile_completion_percentage BETWEEN 0.00 AND 100.00),
    CONSTRAINT chk_cp_salary CHECK (
        (salary_disclosure_status = 'UNDISCLOSED' AND current_salary IS NULL) OR
        (salary_disclosure_status = 'NOT_APPLICABLE' AND current_salary IS NULL) OR
        (salary_disclosure_status = 'DISCLOSED' AND (expected_salary IS NULL OR expected_salary >= 0.00))
    ),
    INDEX idx_candidate_city (current_city_id),
    INDEX idx_candidate_role (current_job_role_id),
    INDEX idx_candidate_experience (total_experience_months),
    INDEX idx_candidate_completion (profile_completion_percentage)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;


-- 2. Candidate Educational Record
CREATE TABLE IF NOT EXISTS candidate_education (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    uuid CHAR(36) NOT NULL DEFAULT (UUID()),
    candidate_profile_id BIGINT UNSIGNED NOT NULL,
    educational_qualification_id BIGINT UNSIGNED NOT NULL,
    institution_name VARCHAR(200) NOT NULL,
    field_of_study VARCHAR(150) NOT NULL,
    start_year INT UNSIGNED NOT NULL,
    graduation_year INT UNSIGNED NOT NULL,
    grade_percentage_or_gpa DECIMAL(5, 2) NULL,
    is_highest_degree BOOLEAN NOT NULL DEFAULT FALSE,
    created_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    created_by BIGINT UNSIGNED NULL,
    updated_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6),
    updated_by BIGINT UNSIGNED NULL,
    deleted_at DATETIME(6) NULL,
    CONSTRAINT pk_candidate_education PRIMARY KEY (id),
    CONSTRAINT uq_candidate_education_uuid UNIQUE (uuid),
    CONSTRAINT fk_ce_candidate_id FOREIGN KEY (candidate_profile_id) REFERENCES candidate_profile (id) ON UPDATE CASCADE ON DELETE CASCADE,
    CONSTRAINT fk_ce_qualification_id FOREIGN KEY (educational_qualification_id) REFERENCES educational_qualification (id) ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT chk_ce_years CHECK (graduation_year >= start_year),
    INDEX idx_ce_candidate_id (candidate_profile_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;


-- 3. Candidate Work Experience
CREATE TABLE IF NOT EXISTS candidate_work_experience (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    uuid CHAR(36) NOT NULL DEFAULT (UUID()),
    candidate_profile_id BIGINT UNSIGNED NOT NULL,
    company_name VARCHAR(150) NOT NULL,
    designation_title VARCHAR(150) NOT NULL,
    employment_type_lookup_id BIGINT UNSIGNED NOT NULL,
    start_date DATE NOT NULL,
    end_date DATE NULL, -- NULL indicates current role
    is_current_job BOOLEAN NOT NULL DEFAULT FALSE,
    job_description TEXT NULL,
    created_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    created_by BIGINT UNSIGNED NULL,
    updated_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6),
    updated_by BIGINT UNSIGNED NULL,
    deleted_at DATETIME(6) NULL,
    CONSTRAINT pk_candidate_work_experience PRIMARY KEY (id),
    CONSTRAINT uq_candidate_work_experience_uuid UNIQUE (uuid),
    CONSTRAINT fk_cwe_candidate_id FOREIGN KEY (candidate_profile_id) REFERENCES candidate_profile (id) ON UPDATE CASCADE ON DELETE CASCADE,
    CONSTRAINT fk_cwe_employment_type_id FOREIGN KEY (employment_type_lookup_id) REFERENCES employment_type_lookup (id) ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT chk_cwe_dates CHECK (end_date IS NULL OR end_date >= start_date),
    INDEX idx_cwe_candidate_id (candidate_profile_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;


-- 4. Candidate Skills Association
CREATE TABLE IF NOT EXISTS candidate_skill (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    candidate_profile_id BIGINT UNSIGNED NOT NULL,
    skill_id BIGINT UNSIGNED NOT NULL,
    proficiency_level_code VARCHAR(30) NOT NULL DEFAULT 'INTERMEDIATE', -- 'BEGINNER', 'INTERMEDIATE', 'ADVANCED', 'EXPERT'
    experience_months INT UNSIGNED NOT NULL DEFAULT 0,
    is_verified_by_test BOOLEAN NOT NULL DEFAULT FALSE,
    created_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    created_by BIGINT UNSIGNED NULL,
    updated_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6),
    updated_by BIGINT UNSIGNED NULL,
    CONSTRAINT pk_candidate_skill PRIMARY KEY (id),
    CONSTRAINT uq_candidate_skill UNIQUE (candidate_profile_id, skill_id),
    CONSTRAINT fk_cs_candidate_id FOREIGN KEY (candidate_profile_id) REFERENCES candidate_profile (id) ON UPDATE CASCADE ON DELETE CASCADE,
    CONSTRAINT fk_cs_skill_id FOREIGN KEY (skill_id) REFERENCES skill (id) ON UPDATE CASCADE ON DELETE RESTRICT,
    INDEX idx_cs_skill_id (skill_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;


-- 5. Candidate Spoken / Written Languages
CREATE TABLE IF NOT EXISTS candidate_language (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    candidate_profile_id BIGINT UNSIGNED NOT NULL,
    spoken_language_id BIGINT UNSIGNED NOT NULL,
    proficiency_level_code VARCHAR(30) NOT NULL DEFAULT 'PROFICIENT', -- 'BASIC', 'CONVERSATIONAL', 'PROFICIENT', 'NATIVE'
    can_read BOOLEAN NOT NULL DEFAULT TRUE,
    can_write BOOLEAN NOT NULL DEFAULT TRUE,
    can_speak BOOLEAN NOT NULL DEFAULT TRUE,
    created_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    created_by BIGINT UNSIGNED NULL,
    CONSTRAINT pk_candidate_language PRIMARY KEY (id),
    CONSTRAINT uq_candidate_language UNIQUE (candidate_profile_id, spoken_language_id),
    CONSTRAINT fk_cl_candidate_id FOREIGN KEY (candidate_profile_id) REFERENCES candidate_profile (id) ON UPDATE CASCADE ON DELETE CASCADE,
    CONSTRAINT fk_cl_language_id FOREIGN KEY (spoken_language_id) REFERENCES spoken_language (id) ON UPDATE CASCADE ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- 6. Candidate Resumes & Templates
CREATE TABLE IF NOT EXISTS candidate_resume (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    uuid CHAR(36) NOT NULL DEFAULT (UUID()),
    candidate_profile_id BIGINT UNSIGNED NOT NULL,
    resume_title VARCHAR(150) NOT NULL,
    file_storage_uri VARCHAR(500) NOT NULL,
    file_mime_type VARCHAR(50) NOT NULL DEFAULT 'application/pdf',
    file_size_bytes INT UNSIGNED NOT NULL,
    resume_raw_text MEDIUMTEXT NULL, -- For ATS full-text indexing
    template_code VARCHAR(50) NOT NULL DEFAULT 'STANDARD_CHRONOLOGICAL',
    is_primary_resume BOOLEAN NOT NULL DEFAULT FALSE,
    created_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    created_by BIGINT UNSIGNED NULL,
    updated_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6),
    updated_by BIGINT UNSIGNED NULL,
    deleted_at DATETIME(6) NULL,
    CONSTRAINT pk_candidate_resume PRIMARY KEY (id),
    CONSTRAINT uq_candidate_resume_uuid UNIQUE (uuid),
    CONSTRAINT fk_cr_candidate_id FOREIGN KEY (candidate_profile_id) REFERENCES candidate_profile (id) ON UPDATE CASCADE ON DELETE CASCADE,
    INDEX idx_cr_candidate_id (candidate_profile_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;


-- 7. Candidate Profile Projects (Full-time & Gig Portfolio)
CREATE TABLE IF NOT EXISTS candidate_project (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    uuid CHAR(36) NOT NULL DEFAULT (UUID()),
    candidate_profile_id BIGINT UNSIGNED NOT NULL,
    project_title VARCHAR(150) NOT NULL,
    project_role_title VARCHAR(100) NOT NULL,
    start_date DATE NOT NULL,
    end_date DATE NULL,
    project_description TEXT NULL,
    project_outcome_summary TEXT NULL,
    portfolio_url VARCHAR(255) NULL,
    created_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    created_by BIGINT UNSIGNED NULL,
    updated_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6),
    updated_by BIGINT UNSIGNED NULL,
    deleted_at DATETIME(6) NULL,
    CONSTRAINT pk_candidate_project PRIMARY KEY (id),
    CONSTRAINT uq_candidate_project_uuid UNIQUE (uuid),
    CONSTRAINT fk_cpj_candidate_id FOREIGN KEY (candidate_profile_id) REFERENCES candidate_profile (id) ON UPDATE CASCADE ON DELETE CASCADE,
    CONSTRAINT chk_cpj_dates CHECK (end_date IS NULL OR end_date >= start_date),
    INDEX idx_cpj_candidate_id (candidate_profile_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;


-- 8. Candidate Assessments & Standardized Test Scores
CREATE TABLE IF NOT EXISTS candidate_assessment (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    uuid CHAR(36) NOT NULL DEFAULT (UUID()),
    candidate_profile_id BIGINT UNSIGNED NOT NULL,
    assessment_title VARCHAR(150) NOT NULL,
    assessment_provider VARCHAR(100) NOT NULL DEFAULT 'TALENTRA_INTERNAL',
    score_achieved DECIMAL(6, 2) NOT NULL,
    score_maximum DECIMAL(6, 2) NOT NULL,
    percentile_rank DECIMAL(5, 2) NULL,
    assessment_date DATE NOT NULL,
    credential_badge_url VARCHAR(255) NULL,
    created_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    created_by BIGINT UNSIGNED NULL,
    CONSTRAINT pk_candidate_assessment PRIMARY KEY (id),
    CONSTRAINT uq_candidate_assessment_uuid UNIQUE (uuid),
    CONSTRAINT fk_ca_candidate_id FOREIGN KEY (candidate_profile_id) REFERENCES candidate_profile (id) ON UPDATE CASCADE ON DELETE CASCADE,
    CONSTRAINT chk_ca_score CHECK (score_achieved <= score_maximum),
    INDEX idx_ca_candidate_id (candidate_profile_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;


-- 9. Course Enrolments & Certifications
CREATE TABLE IF NOT EXISTS candidate_course_enrolment (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    uuid CHAR(36) NOT NULL DEFAULT (UUID()),
    candidate_profile_id BIGINT UNSIGNED NOT NULL,
    course_title VARCHAR(200) NOT NULL,
    issuing_organization VARCHAR(150) NOT NULL,
    issue_date DATE NOT NULL,
    expiry_date DATE NULL,
    certificate_id VARCHAR(100) NULL,
    created_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    created_by BIGINT UNSIGNED NULL,
    CONSTRAINT pk_candidate_course_enrolment PRIMARY KEY (id),
    CONSTRAINT uq_cce_uuid UNIQUE (uuid),
    CONSTRAINT fk_cce_candidate_id FOREIGN KEY (candidate_profile_id) REFERENCES candidate_profile (id) ON UPDATE CASCADE ON DELETE CASCADE,
    CONSTRAINT chk_cce_dates CHECK (expiry_date IS NULL OR expiry_date >= issue_date)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- 10. Append-Only Profile View History (Rule Group 10)
CREATE TABLE IF NOT EXISTS candidate_profile_view_history (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    candidate_profile_id BIGINT UNSIGNED NOT NULL,
    viewer_user_id BIGINT UNSIGNED NOT NULL,
    viewer_organisation_id BIGINT UNSIGNED NULL,
    viewed_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    ip_address VARCHAR(45) NOT NULL,
    CONSTRAINT pk_candidate_profile_view_history PRIMARY KEY (id),
    CONSTRAINT fk_cpvh_candidate_id FOREIGN KEY (candidate_profile_id) REFERENCES candidate_profile (id) ON UPDATE CASCADE ON DELETE CASCADE,
    CONSTRAINT fk_cpvh_viewer_id FOREIGN KEY (viewer_user_id) REFERENCES app_user (id) ON UPDATE CASCADE ON DELETE CASCADE,
    CONSTRAINT fk_cpvh_org_id FOREIGN KEY (viewer_organisation_id) REFERENCES organisation (id) ON UPDATE CASCADE ON DELETE SET NULL,
    INDEX idx_cpvh_candidate (candidate_profile_id, viewed_at),
    INDEX idx_cpvh_viewer (viewer_user_id, viewed_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;


-- 11. Candidate Activity Log (Tier 2 requirement)
CREATE TABLE IF NOT EXISTS candidate_activity_log (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    candidate_profile_id BIGINT UNSIGNED NOT NULL,
    activity_type_code VARCHAR(50) NOT NULL, -- 'LOGIN', 'PROFILE_UPDATE', 'RESUME_DOWNLOAD', 'SEARCH_EXECUTED'
    activity_details JSON NULL,
    activity_timestamp DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    CONSTRAINT pk_candidate_activity_log PRIMARY KEY (id),
    CONSTRAINT fk_cal_candidate_id FOREIGN KEY (candidate_profile_id) REFERENCES candidate_profile (id) ON UPDATE CASCADE ON DELETE CASCADE,
    INDEX idx_cal_candidate_time (candidate_profile_id, activity_timestamp)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;


-- 12. Shortlist & Bookmark History (Tier 2 requirement)
CREATE TABLE IF NOT EXISTS candidate_bookmark (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    organisation_id BIGINT UNSIGNED NOT NULL,
    recruiter_user_id BIGINT UNSIGNED NOT NULL,
    candidate_profile_id BIGINT UNSIGNED NOT NULL,
    bookmark_notes VARCHAR(255) NULL,
    bookmarked_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    CONSTRAINT pk_candidate_bookmark PRIMARY KEY (id),
    CONSTRAINT uq_candidate_bookmark UNIQUE (organisation_id, candidate_profile_id),
    CONSTRAINT fk_cb_org_id FOREIGN KEY (organisation_id) REFERENCES organisation (id) ON UPDATE CASCADE ON DELETE CASCADE,
    CONSTRAINT fk_cb_recruiter_id FOREIGN KEY (recruiter_user_id) REFERENCES app_user (id) ON UPDATE CASCADE ON DELETE CASCADE,
    CONSTRAINT fk_cb_candidate_id FOREIGN KEY (candidate_profile_id) REFERENCES candidate_profile (id) ON UPDATE CASCADE ON DELETE CASCADE,
    INDEX idx_cb_candidate_id (candidate_profile_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;


-- 13. Candidate Referral Tracking
CREATE TABLE IF NOT EXISTS candidate_referral (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    uuid CHAR(36) NOT NULL DEFAULT (UUID()),
    referrer_user_id BIGINT UNSIGNED NOT NULL,
    referred_email_address VARCHAR(254) NOT NULL,
    referred_candidate_profile_id BIGINT UNSIGNED NULL,
    referral_code VARCHAR(50) NOT NULL,
    referral_status_code VARCHAR(50) NOT NULL DEFAULT 'INVITED', -- 'INVITED', 'REGISTERED', 'HIRED', 'EXPIRED'
    created_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    updated_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6),
    CONSTRAINT pk_candidate_referral PRIMARY KEY (id),
    CONSTRAINT uq_candidate_referral_uuid UNIQUE (uuid),
    CONSTRAINT uq_candidate_referral_code UNIQUE (referral_code),
    CONSTRAINT fk_cr_referrer_id FOREIGN KEY (referrer_user_id) REFERENCES app_user (id) ON UPDATE CASCADE ON DELETE CASCADE,
    CONSTRAINT fk_cr_referred_id FOREIGN KEY (referred_candidate_profile_id) REFERENCES candidate_profile (id) ON UPDATE CASCADE ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
