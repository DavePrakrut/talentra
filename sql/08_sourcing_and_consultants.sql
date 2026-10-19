-- ============================================================================
-- Module 8: Sourcing, Consultant Requests & Bulk Outreach
-- Deliverables: Sourcing requests, consultant authorization, acceptance/decline,
--               sourcing shortlists, bulk outreach batches and recipients
-- Compliance: Section 3 (Consultant Rules), Rule Groups 1, 2, 3, 4
-- ============================================================================

USE talentra_db;

-- 1. Consultant Sourcing Engagement Request
CREATE TABLE IF NOT EXISTS consultant_sourcing_request (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    uuid CHAR(36) NOT NULL DEFAULT (UUID()),
    job_requirement_id BIGINT UNSIGNED NOT NULL,
    consultant_user_id BIGINT UNSIGNED NOT NULL,
    initiated_by_actor_type VARCHAR(50) NOT NULL, -- 'EMPLOYER_INVITE', 'CONSULTANT_PITCH'
    commission_rate_percentage DECIMAL(5, 2) NOT NULL,
    request_status_code VARCHAR(50) NOT NULL DEFAULT 'PENDING', -- 'PENDING', 'ACCEPTED', 'DECLINED', 'TERMINATED'
    decision_reason_notes VARCHAR(255) NULL,
    decision_by_user_id BIGINT UNSIGNED NULL,
    decided_at DATETIME(6) NULL,
    created_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    created_by BIGINT UNSIGNED NULL,
    updated_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6),
    updated_by BIGINT UNSIGNED NULL,
    deleted_at DATETIME(6) NULL,
    CONSTRAINT pk_consultant_sourcing_request PRIMARY KEY (id),
    CONSTRAINT uq_consultant_sourcing_request_uuid UNIQUE (uuid),
    CONSTRAINT uq_csr_job_consultant UNIQUE (job_requirement_id, consultant_user_id),
    CONSTRAINT fk_csr_job_id FOREIGN KEY (job_requirement_id) REFERENCES job_requirement (id) ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT fk_csr_consultant_id FOREIGN KEY (consultant_user_id) REFERENCES app_user (id) ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT fk_csr_decision_user_id FOREIGN KEY (decision_by_user_id) REFERENCES app_user (id) ON UPDATE CASCADE ON DELETE SET NULL,
    CONSTRAINT chk_csr_commission CHECK (commission_rate_percentage BETWEEN 0.00 AND 100.00),
    INDEX idx_csr_job_id (job_requirement_id, request_status_code),
    INDEX idx_csr_consultant_id (consultant_user_id, request_status_code)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;


-- 2. Consultant Candidate Sourcing Shortlist
CREATE TABLE IF NOT EXISTS consultant_candidate_shortlist (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    uuid CHAR(36) NOT NULL DEFAULT (UUID()),
    consultant_sourcing_request_id BIGINT UNSIGNED NOT NULL,
    candidate_profile_id BIGINT UNSIGNED NOT NULL,
    submission_notes TEXT NULL,
    client_review_status_code VARCHAR(50) NOT NULL DEFAULT 'PENDING_REVIEW', -- 'PENDING_REVIEW', 'ACCEPTED_TO_PIPELINE', 'REJECTED'
    reviewed_at DATETIME(6) NULL,
    created_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    created_by BIGINT UNSIGNED NULL,
    updated_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6),
    updated_by BIGINT UNSIGNED NULL,
    CONSTRAINT pk_consultant_candidate_shortlist PRIMARY KEY (id),
    CONSTRAINT uq_consultant_candidate_shortlist_uuid UNIQUE (uuid),
    CONSTRAINT uq_ccs_request_candidate UNIQUE (consultant_sourcing_request_id, candidate_profile_id),
    CONSTRAINT fk_ccs_request_id FOREIGN KEY (consultant_sourcing_request_id) REFERENCES consultant_sourcing_request (id) ON UPDATE CASCADE ON DELETE CASCADE,
    CONSTRAINT fk_ccs_candidate_id FOREIGN KEY (candidate_profile_id) REFERENCES candidate_profile (id) ON UPDATE CASCADE ON DELETE RESTRICT,
    INDEX idx_ccs_request (consultant_sourcing_request_id),
    INDEX idx_ccs_candidate (candidate_profile_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;


-- 3. Bulk Outreach Campaign Batches (Employer/Recruiter Sourcing)
CREATE TABLE IF NOT EXISTS bulk_outreach_batch (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    uuid CHAR(36) NOT NULL DEFAULT (UUID()),
    organisation_id BIGINT UNSIGNED NOT NULL,
    recruiter_user_id BIGINT UNSIGNED NOT NULL,
    job_requirement_id BIGINT UNSIGNED NOT NULL,
    campaign_name VARCHAR(150) NOT NULL,
    target_criteria_summary VARCHAR(255) NULL,
    total_recipients_count INT UNSIGNED NOT NULL DEFAULT 0,
    credits_consumed_amount DECIMAL(10, 2) NOT NULL DEFAULT 0.00,
    batch_status_code VARCHAR(50) NOT NULL DEFAULT 'PENDING', -- 'PENDING', 'PROCESSING', 'COMPLETED', 'FAILED'
    dispatched_at DATETIME(6) NULL,
    created_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    created_by BIGINT UNSIGNED NULL,
    updated_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6),
    updated_by BIGINT UNSIGNED NULL,
    CONSTRAINT pk_bulk_outreach_batch PRIMARY KEY (id),
    CONSTRAINT uq_bulk_outreach_batch_uuid UNIQUE (uuid),
    CONSTRAINT fk_bob_organisation_id FOREIGN KEY (organisation_id) REFERENCES organisation (id) ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT fk_bob_recruiter_id FOREIGN KEY (recruiter_user_id) REFERENCES app_user (id) ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT fk_bob_job_id FOREIGN KEY (job_requirement_id) REFERENCES job_requirement (id) ON UPDATE CASCADE ON DELETE RESTRICT,
    INDEX idx_bob_org_time (organisation_id, created_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;


-- 4. Bulk Outreach Recipients
CREATE TABLE IF NOT EXISTS bulk_outreach_recipient (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    bulk_outreach_batch_id BIGINT UNSIGNED NOT NULL,
    candidate_profile_id BIGINT UNSIGNED NOT NULL,
    delivery_status_code VARCHAR(50) NOT NULL DEFAULT 'QUEUED', -- 'QUEUED', 'SENT', 'OPENED', 'RESPONDED', 'OPTED_OUT'
    response_received_at DATETIME(6) NULL,
    sent_at DATETIME(6) NULL,
    CONSTRAINT pk_bulk_outreach_recipient PRIMARY KEY (id),
    CONSTRAINT uq_batch_candidate UNIQUE (bulk_outreach_batch_id, candidate_profile_id),
    CONSTRAINT fk_bor_batch_id FOREIGN KEY (bulk_outreach_batch_id) REFERENCES bulk_outreach_batch (id) ON UPDATE CASCADE ON DELETE CASCADE,
    CONSTRAINT fk_bor_candidate_id FOREIGN KEY (candidate_profile_id) REFERENCES candidate_profile (id) ON UPDATE CASCADE ON DELETE RESTRICT,
    INDEX idx_bor_candidate (candidate_profile_id, delivery_status_code)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

