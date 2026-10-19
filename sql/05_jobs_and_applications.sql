-- ============================================================================
-- Module 5: Job Requirements & Applications Pipeline
-- Deliverables: Job requisitions, questionnaires, multi-stage application pipeline,
--               interview scheduling, status history, candidate search logs
-- Compliance: Rule Groups 1, 2, 3, 4, 5, 8
-- ============================================================================

USE talentra_db;

-- 1. Job Requirement / Requisition Core
CREATE TABLE IF NOT EXISTS job_requirement (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    uuid CHAR(36) NOT NULL DEFAULT (UUID()),
    organisation_id BIGINT UNSIGNED NOT NULL,
    office_location_id BIGINT UNSIGNED NULL,
    job_role_id BIGINT UNSIGNED NOT NULL,
    employment_type_lookup_id BIGINT UNSIGNED NOT NULL,
    work_mode_lookup_id BIGINT UNSIGNED NOT NULL,
    job_title VARCHAR(150) NOT NULL,
    job_description MEDIUMTEXT NOT NULL,
    positions_count INT UNSIGNED NOT NULL DEFAULT 1,
    positions_filled_count INT UNSIGNED NOT NULL DEFAULT 0,
    minimum_experience_months INT UNSIGNED NOT NULL DEFAULT 0,
    maximum_experience_months INT UNSIGNED NULL,
    minimum_salary DECIMAL(14, 2) NULL,
    maximum_salary DECIMAL(14, 2) NULL,
    salary_currency_code CHAR(3) NOT NULL DEFAULT 'INR',
    is_salary_negotiable BOOLEAN NOT NULL DEFAULT TRUE,
    publish_state_code VARCHAR(50) NOT NULL DEFAULT 'DRAFT', -- 'DRAFT', 'PUBLISHED', 'PAUSED', 'CLOSED', 'ARCHIVED'
    is_open_to_consultants BOOLEAN NOT NULL DEFAULT FALSE,
    open_date DATE NOT NULL,
    close_date DATE NULL,
    created_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    created_by BIGINT UNSIGNED NULL,
    updated_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6),
    updated_by BIGINT UNSIGNED NULL,
    deleted_at DATETIME(6) NULL,
    CONSTRAINT pk_job_requirement PRIMARY KEY (id),
    CONSTRAINT uq_job_requirement_uuid UNIQUE (uuid),
    CONSTRAINT fk_jr_organisation_id FOREIGN KEY (organisation_id) REFERENCES organisation (id) ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT fk_jr_office_location_id FOREIGN KEY (office_location_id) REFERENCES office_location (id) ON UPDATE CASCADE ON DELETE SET NULL,
    CONSTRAINT fk_jr_job_role_id FOREIGN KEY (job_role_id) REFERENCES job_role (id) ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT fk_jr_employment_type_id FOREIGN KEY (employment_type_lookup_id) REFERENCES employment_type_lookup (id) ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT fk_jr_work_mode_id FOREIGN KEY (work_mode_lookup_id) REFERENCES work_mode_lookup (id) ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT chk_jr_positions CHECK (positions_count > 0 AND positions_filled_count <= positions_count),
    CONSTRAINT chk_jr_dates CHECK (close_date IS NULL OR close_date >= open_date),
    CONSTRAINT chk_jr_salary CHECK (maximum_salary IS NULL OR minimum_salary IS NULL OR maximum_salary >= minimum_salary),
    CONSTRAINT chk_jr_exp CHECK (maximum_experience_months IS NULL OR maximum_experience_months >= minimum_experience_months),
    INDEX idx_jr_org_id (organisation_id, publish_state_code),
    INDEX idx_jr_role_id (job_role_id),
    INDEX idx_jr_publish_state (publish_state_code, open_date),
    INDEX idx_jr_consultant_open (is_open_to_consultants, publish_state_code)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;


-- 2. Job Required Skills Mapping
CREATE TABLE IF NOT EXISTS job_requirement_skill (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    job_requirement_id BIGINT UNSIGNED NOT NULL,
    skill_id BIGINT UNSIGNED NOT NULL,
    is_mandatory BOOLEAN NOT NULL DEFAULT TRUE,
    minimum_experience_months INT UNSIGNED NOT NULL DEFAULT 0,
    created_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    created_by BIGINT UNSIGNED NULL,
    CONSTRAINT pk_job_requirement_skill PRIMARY KEY (id),
    CONSTRAINT uq_jr_skill UNIQUE (job_requirement_id, skill_id),
    CONSTRAINT fk_jrs_job_id FOREIGN KEY (job_requirement_id) REFERENCES job_requirement (id) ON UPDATE CASCADE ON DELETE CASCADE,
    CONSTRAINT fk_jrs_skill_id FOREIGN KEY (skill_id) REFERENCES skill (id) ON UPDATE CASCADE ON DELETE RESTRICT,
    INDEX idx_jrs_skill_id (skill_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;


-- 3. Screening Questionnaire Attached to Jobs
CREATE TABLE IF NOT EXISTS job_questionnaire (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    uuid CHAR(36) NOT NULL DEFAULT (UUID()),
    job_requirement_id BIGINT UNSIGNED NOT NULL,
    questionnaire_title VARCHAR(150) NOT NULL,
    passing_score_percentage DECIMAL(5, 2) NOT NULL DEFAULT 60.00,
    is_mandatory BOOLEAN NOT NULL DEFAULT TRUE,
    created_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    created_by BIGINT UNSIGNED NULL,
    updated_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6),
    updated_by BIGINT UNSIGNED NULL,
    CONSTRAINT pk_job_questionnaire PRIMARY KEY (id),
    CONSTRAINT uq_job_questionnaire_uuid UNIQUE (uuid),
    CONSTRAINT fk_jq_job_id FOREIGN KEY (job_requirement_id) REFERENCES job_requirement (id) ON UPDATE CASCADE ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- 4. Screening Questions
CREATE TABLE IF NOT EXISTS job_question (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    job_questionnaire_id BIGINT UNSIGNED NOT NULL,
    question_text TEXT NOT NULL,
    question_type_code VARCHAR(50) NOT NULL, -- 'SINGLE_CHOICE', 'MULTIPLE_CHOICE', 'FREE_TEXT', 'NUMERIC'
    options_json JSON NULL,
    correct_answer_json JSON NULL,
    score_weight DECIMAL(5, 2) NOT NULL DEFAULT 1.00,
    is_knockout BOOLEAN NOT NULL DEFAULT FALSE, -- If failed, candidate is automatically rejected
    sort_order INT NOT NULL DEFAULT 0,
    CONSTRAINT pk_job_question PRIMARY KEY (id),
    CONSTRAINT fk_jq_questionnaire_id FOREIGN KEY (job_questionnaire_id) REFERENCES job_questionnaire (id) ON UPDATE CASCADE ON DELETE CASCADE,
    INDEX idx_jq_questionnaire_id (job_questionnaire_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;


-- 5. Job Application (Core Hiring Pipeline)
CREATE TABLE IF NOT EXISTS job_application (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    uuid CHAR(36) NOT NULL DEFAULT (UUID()),
    job_requirement_id BIGINT UNSIGNED NOT NULL,
    candidate_profile_id BIGINT UNSIGNED NOT NULL,
    candidate_resume_id BIGINT UNSIGNED NOT NULL,
    application_status_code VARCHAR(50) NOT NULL DEFAULT 'APPLIED', -- 'APPLIED', 'SHORTLISTED', 'INTERVIEWED', 'OFFERED', 'JOINED', 'REJECTED', 'WITHDRAWN'
    match_score_percentage DECIMAL(5, 2) NOT NULL DEFAULT 0.00,
    sourcing_channel_code VARCHAR(50) NOT NULL DEFAULT 'DIRECT_APPLY', -- 'DIRECT_APPLY', 'RECRUITER_SOURCED', 'CONSULTANT_REFERRAL', 'EMPLOYEE_REFERRAL'
    applied_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    shortlisted_at DATETIME(6) NULL,
    interviewed_at DATETIME(6) NULL,
    offered_at DATETIME(6) NULL,
    joined_at DATETIME(6) NULL,
    rejected_at DATETIME(6) NULL,
    rejection_reason_code VARCHAR(100) NULL,
    created_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    created_by BIGINT UNSIGNED NULL,
    updated_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6),
    updated_by BIGINT UNSIGNED NULL,
    deleted_at DATETIME(6) NULL,
    CONSTRAINT pk_job_application PRIMARY KEY (id),
    CONSTRAINT uq_job_application_uuid UNIQUE (uuid),
    CONSTRAINT uq_candidate_job_application UNIQUE (job_requirement_id, candidate_profile_id),
    CONSTRAINT fk_ja_job_id FOREIGN KEY (job_requirement_id) REFERENCES job_requirement (id) ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT fk_ja_candidate_id FOREIGN KEY (candidate_profile_id) REFERENCES candidate_profile (id) ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT fk_ja_resume_id FOREIGN KEY (candidate_resume_id) REFERENCES candidate_resume (id) ON UPDATE CASCADE ON DELETE RESTRICT,
    INDEX idx_ja_candidate_id (candidate_profile_id),
    INDEX idx_ja_status (job_requirement_id, application_status_code),
    INDEX idx_ja_applied_at (applied_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;


-- 6. Questionnaire Response Recorded per Application
CREATE TABLE IF NOT EXISTS job_questionnaire_response (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    job_application_id BIGINT UNSIGNED NOT NULL,
    job_question_id BIGINT UNSIGNED NOT NULL,
    candidate_response_json JSON NOT NULL,
    is_correct BOOLEAN NULL,
    score_awarded DECIMAL(5, 2) NOT NULL DEFAULT 0.00,
    evaluated_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    CONSTRAINT pk_job_questionnaire_response PRIMARY KEY (id),
    CONSTRAINT uq_application_question_response UNIQUE (job_application_id, job_question_id),
    CONSTRAINT fk_jqr_application_id FOREIGN KEY (job_application_id) REFERENCES job_application (id) ON UPDATE CASCADE ON DELETE CASCADE,
    CONSTRAINT fk_jqr_question_id FOREIGN KEY (job_question_id) REFERENCES job_question (id) ON UPDATE CASCADE ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- 7. Job Interview Scheduling
CREATE TABLE IF NOT EXISTS job_interview (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    uuid CHAR(36) NOT NULL DEFAULT (UUID()),
    job_application_id BIGINT UNSIGNED NOT NULL,
    interviewer_user_id BIGINT UNSIGNED NOT NULL,
    interview_round_number INT UNSIGNED NOT NULL DEFAULT 1,
    interview_type_code VARCHAR(50) NOT NULL, -- 'TECHNICAL_ROUND_1', 'TECHNICAL_ROUND_2', 'BEHAVIORAL', 'MANAGERIAL', 'HR_ROUND'
    scheduled_start_time DATETIME(6) NOT NULL,
    scheduled_end_time DATETIME(6) NOT NULL,
    meeting_link_or_room VARCHAR(255) NULL,
    interview_status_code VARCHAR(50) NOT NULL DEFAULT 'SCHEDULED', -- 'SCHEDULED', 'COMPLETED', 'CANCELLED', 'NO_SHOW'
    interviewer_rating DECIMAL(3, 1) NULL, -- E.g. 4.5 / 5.0
    interviewer_feedback TEXT NULL,
    created_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    created_by BIGINT UNSIGNED NULL,
    updated_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6),
    updated_by BIGINT UNSIGNED NULL,
    CONSTRAINT pk_job_interview PRIMARY KEY (id),
    CONSTRAINT uq_job_interview_uuid UNIQUE (uuid),
    CONSTRAINT fk_ji_application_id FOREIGN KEY (job_application_id) REFERENCES job_application (id) ON UPDATE CASCADE ON DELETE CASCADE,
    CONSTRAINT fk_ji_interviewer_id FOREIGN KEY (interviewer_user_id) REFERENCES app_user (id) ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT chk_ji_time CHECK (scheduled_end_time >= scheduled_start_time),
    INDEX idx_ji_application_id (job_application_id),
    INDEX idx_ji_interviewer_time (interviewer_user_id, scheduled_start_time)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;


-- 8. Append-Only Status Pipeline History
CREATE TABLE IF NOT EXISTS job_application_status_history (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    job_application_id BIGINT UNSIGNED NOT NULL,
    previous_status_code VARCHAR(50) NULL,
    new_status_code VARCHAR(50) NOT NULL,
    changed_by_user_id BIGINT UNSIGNED NOT NULL,
    change_reason_notes VARCHAR(255) NULL,
    changed_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    CONSTRAINT pk_job_application_status_history PRIMARY KEY (id),
    CONSTRAINT fk_jash_application_id FOREIGN KEY (job_application_id) REFERENCES job_application (id) ON UPDATE CASCADE ON DELETE CASCADE,
    CONSTRAINT fk_jash_user_id FOREIGN KEY (changed_by_user_id) REFERENCES app_user (id) ON UPDATE CASCADE ON DELETE RESTRICT,
    INDEX idx_jash_application_id (job_application_id, changed_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;


-- 9. Candidate Job Search History (Tier 2 requirement)
CREATE TABLE IF NOT EXISTS candidate_job_search_history (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    candidate_profile_id BIGINT UNSIGNED NOT NULL,
    search_keywords VARCHAR(255) NULL,
    search_filters_json JSON NULL,
    result_count INT UNSIGNED NOT NULL DEFAULT 0,
    searched_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    CONSTRAINT pk_candidate_job_search_history PRIMARY KEY (id),
    CONSTRAINT fk_cjsh_candidate_id FOREIGN KEY (candidate_profile_id) REFERENCES candidate_profile (id) ON UPDATE CASCADE ON DELETE CASCADE,
    INDEX idx_cjsh_candidate_time (candidate_profile_id, searched_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

