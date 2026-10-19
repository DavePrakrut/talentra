-- ============================================================================
-- Module 6: Gig Marketplace & On-Demand Workforce Subsystem
-- Deliverables: Gig requests, gig worker profiles, availability calendars,
--               gig applications, assignments, ratings, favorites/blacklists,
--               external fulfilment handoffs, earnings integration boundaries
-- Compliance: Section 2 (Gig Rules), Rule Groups 1, 2, 3, 4, 10
-- ============================================================================

USE talentra_db;

-- 1. Dedicated Gig Worker Profile (Separate from traditional CV)
CREATE TABLE IF NOT EXISTS gig_worker_profile (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    uuid CHAR(36) NOT NULL DEFAULT (UUID()),
    app_user_id BIGINT UNSIGNED NOT NULL,
    headline VARCHAR(150) NOT NULL,
    service_offerings_summary TEXT NOT NULL,
    hourly_charge_rate DECIMAL(10, 2) NOT NULL,
    charge_currency_code CHAR(3) NOT NULL DEFAULT 'INR',
    payout_mode_code VARCHAR(50) NOT NULL DEFAULT 'BANK_TRANSFER',
    overall_rating_average DECIMAL(3, 2) NOT NULL DEFAULT 0.00,
    completed_gigs_count INT UNSIGNED NOT NULL DEFAULT 0,
    is_available_for_instant_dispatch BOOLEAN NOT NULL DEFAULT TRUE,
    created_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    created_by BIGINT UNSIGNED NULL,
    updated_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6),
    updated_by BIGINT UNSIGNED NULL,
    deleted_at DATETIME(6) NULL,
    CONSTRAINT pk_gig_worker_profile PRIMARY KEY (id),
    CONSTRAINT uq_gig_worker_profile_uuid UNIQUE (uuid),
    CONSTRAINT uq_gwp_app_user_id UNIQUE (app_user_id),
    CONSTRAINT fk_gwp_app_user_id FOREIGN KEY (app_user_id) REFERENCES app_user (id) ON UPDATE CASCADE ON DELETE CASCADE,
    CONSTRAINT chk_gwp_charge_rate CHECK (hourly_charge_rate > 0.00),
    CONSTRAINT chk_gwp_rating CHECK (overall_rating_average BETWEEN 0.00 AND 5.00),
    INDEX idx_gwp_charge_rate (hourly_charge_rate),
    INDEX idx_gwp_rating (overall_rating_average)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;


-- 2. Gig Worker Availability Windows
CREATE TABLE IF NOT EXISTS gig_availability (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    uuid CHAR(36) NOT NULL DEFAULT (UUID()),
    gig_worker_profile_id BIGINT UNSIGNED NOT NULL,
    available_start_time DATETIME(6) NOT NULL,
    available_end_time DATETIME(6) NOT NULL,
    is_booked BOOLEAN NOT NULL DEFAULT FALSE,
    created_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    created_by BIGINT UNSIGNED NULL,
    updated_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6),
    updated_by BIGINT UNSIGNED NULL,
    CONSTRAINT pk_gig_availability PRIMARY KEY (id),
    CONSTRAINT uq_gig_availability_uuid UNIQUE (uuid),
    CONSTRAINT fk_ga_worker_id FOREIGN KEY (gig_worker_profile_id) REFERENCES gig_worker_profile (id) ON UPDATE CASCADE ON DELETE CASCADE,
    CONSTRAINT chk_ga_window CHECK (available_end_time > available_start_time),
    INDEX idx_ga_worker_window (gig_worker_profile_id, available_start_time, available_end_time)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;


-- 3. Gig Request (Short-duration, project-based)
CREATE TABLE IF NOT EXISTS gig_request (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    uuid CHAR(36) NOT NULL DEFAULT (UUID()),
    organisation_id BIGINT UNSIGNED NOT NULL,
    requester_user_id BIGINT UNSIGNED NOT NULL,
    city_id BIGINT UNSIGNED NOT NULL,
    gig_title VARCHAR(150) NOT NULL,
    gig_description TEXT NOT NULL,
    pricing_model_code VARCHAR(50) NOT NULL, -- 'FIXED_PRICE', 'HOURLY_RATE'
    budget_amount DECIMAL(14, 2) NOT NULL,
    budget_currency_code CHAR(3) NOT NULL DEFAULT 'INR',
    window_start_time DATETIME(6) NOT NULL,
    window_end_time DATETIME(6) NOT NULL,
    gig_status_code VARCHAR(50) NOT NULL DEFAULT 'OPEN', -- 'OPEN', 'ASSIGNED', 'IN_FULFILMENT', 'COMPLETED', 'CANCELLED'
    workers_needed_count INT UNSIGNED NOT NULL DEFAULT 1,
    created_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    created_by BIGINT UNSIGNED NULL,
    updated_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6),
    updated_by BIGINT UNSIGNED NULL,
    deleted_at DATETIME(6) NULL,
    CONSTRAINT pk_gig_request PRIMARY KEY (id),
    CONSTRAINT uq_gig_request_uuid UNIQUE (uuid),
    CONSTRAINT fk_gr_organisation_id FOREIGN KEY (organisation_id) REFERENCES organisation (id) ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT fk_gr_requester_id FOREIGN KEY (requester_user_id) REFERENCES app_user (id) ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT fk_gr_city_id FOREIGN KEY (city_id) REFERENCES city (id) ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT chk_gr_budget CHECK (budget_amount > 0.00),
    CONSTRAINT chk_gr_window CHECK (window_end_time > window_start_time),
    CONSTRAINT chk_gr_workers CHECK (workers_needed_count > 0),
    INDEX idx_gr_org_id (organisation_id, gig_status_code),
    INDEX idx_gr_window (window_start_time, window_end_time),
    INDEX idx_gr_city (city_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;


-- 4. Gig Application (Workers apply; bids do not flow both directions)
CREATE TABLE IF NOT EXISTS gig_application (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    uuid CHAR(36) NOT NULL DEFAULT (UUID()),
    gig_request_id BIGINT UNSIGNED NOT NULL,
    gig_worker_profile_id BIGINT UNSIGNED NOT NULL,
    proposed_bid_rate DECIMAL(10, 2) NOT NULL,
    application_pitch TEXT NULL,
    application_status_code VARCHAR(50) NOT NULL DEFAULT 'PENDING', -- 'PENDING', 'ACCEPTED', 'REJECTED', 'WITHDRAWN'
    decision_reason_notes VARCHAR(255) NULL,
    applied_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    decided_at DATETIME(6) NULL,
    created_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    created_by BIGINT UNSIGNED NULL,
    updated_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6),
    updated_by BIGINT UNSIGNED NULL,
    CONSTRAINT pk_gig_application PRIMARY KEY (id),
    CONSTRAINT uq_gig_application_uuid UNIQUE (uuid),
    CONSTRAINT uq_worker_gig_application UNIQUE (gig_request_id, gig_worker_profile_id),
    CONSTRAINT fk_gap_request_id FOREIGN KEY (gig_request_id) REFERENCES gig_request (id) ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT fk_gap_worker_id FOREIGN KEY (gig_worker_profile_id) REFERENCES gig_worker_profile (id) ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT chk_gap_bid CHECK (proposed_bid_rate > 0.00),
    INDEX idx_gap_worker_id (gig_worker_profile_id),
    INDEX idx_gap_status (gig_request_id, application_status_code)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;


-- 5. Gig Assignment & External Fulfilment Handoff Reference (Milestone 8, 10)
CREATE TABLE IF NOT EXISTS gig_assignment (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    uuid CHAR(36) NOT NULL DEFAULT (UUID()),
    gig_request_id BIGINT UNSIGNED NOT NULL,
    gig_application_id BIGINT UNSIGNED NOT NULL,
    gig_worker_profile_id BIGINT UNSIGNED NOT NULL,
    scheduled_start_time DATETIME(6) NOT NULL,
    scheduled_end_time DATETIME(6) NOT NULL,
    agreed_payout_amount DECIMAL(14, 2) NOT NULL,
    payout_currency_code CHAR(3) NOT NULL DEFAULT 'INR',
    assignment_status_code VARCHAR(50) NOT NULL DEFAULT 'ASSIGNED', -- 'ASSIGNED', 'IN_FULFILMENT', 'FULFILLED', 'DISPUTED', 'CANCELLED'
    external_fulfilment_system_code VARCHAR(50) NOT NULL DEFAULT 'NORTHBRIDGE_FULFIL_V1',
    external_handoff_reference_id VARCHAR(100) NOT NULL, -- Correlation token for external fulfilment system
    last_synced_at DATETIME(6) NULL,
    created_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    created_by BIGINT UNSIGNED NULL,
    updated_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6),
    updated_by BIGINT UNSIGNED NULL,
    CONSTRAINT pk_gig_assignment PRIMARY KEY (id),
    CONSTRAINT uq_gig_assignment_uuid UNIQUE (uuid),
    CONSTRAINT uq_ga_handoff_ref UNIQUE (external_handoff_reference_id),
    CONSTRAINT fk_gas_request_id FOREIGN KEY (gig_request_id) REFERENCES gig_request (id) ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT fk_gas_application_id FOREIGN KEY (gig_application_id) REFERENCES gig_application (id) ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT fk_gas_worker_id FOREIGN KEY (gig_worker_profile_id) REFERENCES gig_worker_profile (id) ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT chk_gas_window CHECK (scheduled_end_time > scheduled_start_time),
    CONSTRAINT chk_gas_payout CHECK (agreed_payout_amount >= 0.00),
    INDEX idx_gas_worker_schedule (gig_worker_profile_id, scheduled_start_time, scheduled_end_time),
    INDEX idx_gas_request_id (gig_request_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;


-- 6. External Earnings Reference (Integration Boundary 4)
CREATE TABLE IF NOT EXISTS gig_earnings_reference (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    uuid CHAR(36) NOT NULL DEFAULT (UUID()),
    gig_assignment_id BIGINT UNSIGNED NOT NULL,
    gig_worker_profile_id BIGINT UNSIGNED NOT NULL,
    estimated_earnings DECIMAL(14, 2) NOT NULL DEFAULT 0.00,
    reconciled_earnings DECIMAL(14, 2) NOT NULL DEFAULT 0.00,
    projected_earnings DECIMAL(14, 2) NOT NULL DEFAULT 0.00,
    currency_code CHAR(3) NOT NULL DEFAULT 'INR',
    reconciliation_status_code VARCHAR(50) NOT NULL DEFAULT 'PENDING_RECONCILIATION', -- 'PENDING_RECONCILIATION', 'RECONCILED', 'DISPUTED', 'SETTLED'
    external_ledger_tx_id VARCHAR(100) NULL,
    reconciled_at DATETIME(6) NULL,
    created_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    created_by BIGINT UNSIGNED NULL,
    updated_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6),
    updated_by BIGINT UNSIGNED NULL,
    CONSTRAINT pk_gig_earnings_reference PRIMARY KEY (id),
    CONSTRAINT uq_gig_earnings_reference_uuid UNIQUE (uuid),
    CONSTRAINT uq_ger_assignment_id UNIQUE (gig_assignment_id),
    CONSTRAINT fk_ger_assignment_id FOREIGN KEY (gig_assignment_id) REFERENCES gig_assignment (id) ON UPDATE CASCADE ON DELETE CASCADE,
    CONSTRAINT fk_ger_worker_id FOREIGN KEY (gig_worker_profile_id) REFERENCES gig_worker_profile (id) ON UPDATE CASCADE ON DELETE RESTRICT,
    INDEX idx_ger_worker (gig_worker_profile_id, reconciliation_status_code)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;


-- 7. Requester Gig Ratings (Requesters rate completed gigs)
CREATE TABLE IF NOT EXISTS gig_rating (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    uuid CHAR(36) NOT NULL DEFAULT (UUID()),
    gig_assignment_id BIGINT UNSIGNED NOT NULL,
    requester_user_id BIGINT UNSIGNED NOT NULL,
    gig_worker_profile_id BIGINT UNSIGNED NOT NULL,
    rating_score DECIMAL(2, 1) NOT NULL, -- 1.0 to 5.0
    quality_score DECIMAL(2, 1) NOT NULL,
    punctuality_score DECIMAL(2, 1) NOT NULL,
    feedback_review_text TEXT NULL,
    created_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    created_by BIGINT UNSIGNED NULL,
    CONSTRAINT pk_gig_rating PRIMARY KEY (id),
    CONSTRAINT uq_gig_rating_uuid UNIQUE (uuid),
    CONSTRAINT uq_gr_assignment UNIQUE (gig_assignment_id),
    CONSTRAINT fk_gr_assignment_id FOREIGN KEY (gig_assignment_id) REFERENCES gig_assignment (id) ON UPDATE CASCADE ON DELETE CASCADE,
    CONSTRAINT fk_gr_requester_user_id FOREIGN KEY (requester_user_id) REFERENCES app_user (id) ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT fk_gr_worker_profile_id FOREIGN KEY (gig_worker_profile_id) REFERENCES gig_worker_profile (id) ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT chk_gr_score CHECK (rating_score BETWEEN 1.0 AND 5.0),
    CONSTRAINT chk_gr_quality CHECK (quality_score BETWEEN 1.0 AND 5.0),
    CONSTRAINT chk_gr_punctuality CHECK (punctuality_score BETWEEN 1.0 AND 5.0),
    INDEX idx_gr_worker_rating (gig_worker_profile_id, rating_score)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;


-- 8. Requester Favourite Gig Workers Pool
CREATE TABLE IF NOT EXISTS gig_favorite_worker (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    organisation_id BIGINT UNSIGNED NOT NULL,
    gig_worker_profile_id BIGINT UNSIGNED NOT NULL,
    notes VARCHAR(255) NULL,
    created_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    created_by BIGINT UNSIGNED NULL,
    CONSTRAINT pk_gig_favorite_worker PRIMARY KEY (id),
    CONSTRAINT uq_org_fav_worker UNIQUE (organisation_id, gig_worker_profile_id),
    CONSTRAINT fk_gfw_org_id FOREIGN KEY (organisation_id) REFERENCES organisation (id) ON UPDATE CASCADE ON DELETE CASCADE,
    CONSTRAINT fk_gfw_worker_id FOREIGN KEY (gig_worker_profile_id) REFERENCES gig_worker_profile (id) ON UPDATE CASCADE ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- 9. Requester Blacklisted Gig Workers (Block from viewing or applying to org gigs)
CREATE TABLE IF NOT EXISTS gig_blacklist_worker (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    organisation_id BIGINT UNSIGNED NOT NULL,
    gig_worker_profile_id BIGINT UNSIGNED NOT NULL,
    blacklist_reason VARCHAR(255) NOT NULL,
    blacklisted_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    blacklisted_by BIGINT UNSIGNED NOT NULL,
    CONSTRAINT pk_gig_blacklist_worker PRIMARY KEY (id),
    CONSTRAINT uq_org_blacklisted_worker UNIQUE (organisation_id, gig_worker_profile_id),
    CONSTRAINT fk_gbw_org_id FOREIGN KEY (organisation_id) REFERENCES organisation (id) ON UPDATE CASCADE ON DELETE CASCADE,
    CONSTRAINT fk_gbw_worker_id FOREIGN KEY (gig_worker_profile_id) REFERENCES gig_worker_profile (id) ON UPDATE CASCADE ON DELETE CASCADE,
    CONSTRAINT fk_gbw_actor_id FOREIGN KEY (blacklisted_by) REFERENCES app_user (id) ON UPDATE CASCADE ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
