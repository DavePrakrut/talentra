-- ============================================================================
-- Module 11: Analytics Layer, Reporting Marts & Tier 3 Stretch Coverage
-- Deliverables: Star schema conformed dimensions (dim_*), event facts (fact_*),
--               KPI aggregation rollups (agg_*), and Tier 3 benchmarks & feature flags
-- Compliance: Rule Groups 1, 2, 8
-- ============================================================================

USE talentra_db;

-- 1. Conformed Date & Time Dimension
CREATE TABLE IF NOT EXISTS dim_time (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    date_actual DATE NOT NULL,
    calendar_year INT NOT NULL,
    calendar_quarter INT NOT NULL,
    calendar_month INT NOT NULL,
    month_name VARCHAR(20) NOT NULL,
    calendar_week INT NOT NULL,
    day_of_month INT NOT NULL,
    day_of_week INT NOT NULL,
    day_name VARCHAR(20) NOT NULL,
    is_weekend BOOLEAN NOT NULL,
    fiscal_quarter VARCHAR(10) NOT NULL,
    CONSTRAINT pk_dim_time PRIMARY KEY (id),
    CONSTRAINT uq_dim_time_date UNIQUE (date_actual),
    INDEX idx_dim_time_lookup (calendar_year, calendar_month)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;


-- 2. Conformed Job Dimension (SCD Type 1 / 2 support)
CREATE TABLE IF NOT EXISTS dim_job (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    job_requirement_id BIGINT UNSIGNED NOT NULL,
    organisation_id BIGINT UNSIGNED NOT NULL,
    job_title VARCHAR(150) NOT NULL,
    job_role_name VARCHAR(150) NOT NULL,
    industry_name VARCHAR(150) NOT NULL,
    employment_type_name VARCHAR(100) NOT NULL,
    work_mode_name VARCHAR(100) NOT NULL,
    is_open_to_consultants BOOLEAN NOT NULL,
    publish_state_code VARCHAR(50) NOT NULL,
    created_date DATE NOT NULL,
    CONSTRAINT pk_dim_job PRIMARY KEY (id),
    CONSTRAINT uq_dim_job_requirement UNIQUE (job_requirement_id),
    INDEX idx_dim_job_org (organisation_id),
    INDEX idx_dim_job_industry (industry_name)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;


-- 3. Conformed Candidate Dimension
CREATE TABLE IF NOT EXISTS dim_candidate (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    candidate_profile_id BIGINT UNSIGNED NOT NULL,
    city_name VARCHAR(150) NULL,
    experience_tier_code VARCHAR(50) NOT NULL, -- 'FRESHER', 'JUNIOR_1_3', 'MID_4_7', 'SENIOR_8_12', 'LEAD_13_PLUS'
    highest_qualification_level VARCHAR(50) NULL,
    profile_completion_percentage DECIMAL(5, 2) NOT NULL,
    is_actively_looking BOOLEAN NOT NULL,
    registered_date DATE NOT NULL,
    CONSTRAINT pk_dim_candidate PRIMARY KEY (id),
    CONSTRAINT uq_dim_candidate_profile UNIQUE (candidate_profile_id),
    INDEX idx_dim_candidate_exp (experience_tier_code)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;


-- 4. Conformed Organisation Dimension
CREATE TABLE IF NOT EXISTS dim_organisation (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    organisation_id BIGINT UNSIGNED NOT NULL,
    legal_name VARCHAR(200) NOT NULL,
    trade_name VARCHAR(150) NOT NULL,
    organisation_type_code VARCHAR(50) NOT NULL,
    industry_name VARCHAR(150) NOT NULL,
    verification_status_code VARCHAR(50) NOT NULL,
    account_status_code VARCHAR(50) NOT NULL,
    CONSTRAINT pk_dim_organisation PRIMARY KEY (id),
    CONSTRAINT uq_dim_organisation_id UNIQUE (organisation_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- 5. Application Pipeline Event Fact
CREATE TABLE IF NOT EXISTS fact_application_event (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    dim_time_id BIGINT UNSIGNED NOT NULL,
    dim_job_id BIGINT UNSIGNED NOT NULL,
    dim_candidate_id BIGINT UNSIGNED NOT NULL,
    dim_organisation_id BIGINT UNSIGNED NOT NULL,
    job_application_id BIGINT UNSIGNED NOT NULL,
    sourcing_channel_code VARCHAR(50) NOT NULL,
    match_score_percentage DECIMAL(5, 2) NOT NULL,
    is_applied INT UNSIGNED NOT NULL DEFAULT 1,
    is_shortlisted INT UNSIGNED NOT NULL DEFAULT 0,
    is_interviewed INT UNSIGNED NOT NULL DEFAULT 0,
    is_offered INT UNSIGNED NOT NULL DEFAULT 0,
    is_joined INT UNSIGNED NOT NULL DEFAULT 0,
    is_rejected INT UNSIGNED NOT NULL DEFAULT 0,
    days_to_shortlist INT UNSIGNED NULL,
    days_to_interview INT UNSIGNED NULL,
    days_to_offer INT UNSIGNED NULL,
    days_to_join INT UNSIGNED NULL,
    event_timestamp DATETIME(6) NOT NULL,
    CONSTRAINT pk_fact_application_event PRIMARY KEY (id),
    CONSTRAINT fk_fae_time FOREIGN KEY (dim_time_id) REFERENCES dim_time (id),
    CONSTRAINT fk_fae_job FOREIGN KEY (dim_job_id) REFERENCES dim_job (id),
    CONSTRAINT fk_fae_candidate FOREIGN KEY (dim_candidate_id) REFERENCES dim_candidate (id),
    CONSTRAINT fk_fae_organisation FOREIGN KEY (dim_organisation_id) REFERENCES dim_organisation (id),
    INDEX idx_fae_funnel (dim_organisation_id, dim_time_id),
    INDEX idx_fae_channel (sourcing_channel_code)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;


-- 6. Commercial Wallet & Revenue Fact
CREATE TABLE IF NOT EXISTS fact_wallet_transaction (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    dim_time_id BIGINT UNSIGNED NOT NULL,
    dim_organisation_id BIGINT UNSIGNED NOT NULL,
    transaction_type_code VARCHAR(50) NOT NULL,
    transaction_amount DECIMAL(14, 2) NOT NULL,
    credit_deduction_count INT UNSIGNED NOT NULL DEFAULT 0,
    transaction_timestamp DATETIME(6) NOT NULL,
    CONSTRAINT pk_fact_wallet_transaction PRIMARY KEY (id),
    CONSTRAINT fk_fwt_time FOREIGN KEY (dim_time_id) REFERENCES dim_time (id),
    CONSTRAINT fk_fwt_organisation FOREIGN KEY (dim_organisation_id) REFERENCES dim_organisation (id),
    INDEX idx_fwt_org_time (dim_organisation_id, dim_time_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;


-- 7. Monthly Hiring Funnel Aggregate Mart
CREATE TABLE IF NOT EXISTS agg_monthly_hiring_funnel (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    calendar_year INT NOT NULL,
    calendar_month INT NOT NULL,
    organisation_id BIGINT UNSIGNED NOT NULL,
    job_role_id BIGINT UNSIGNED NOT NULL,
    total_applications_count INT UNSIGNED NOT NULL DEFAULT 0,
    shortlisted_count INT UNSIGNED NOT NULL DEFAULT 0,
    interviewed_count INT UNSIGNED NOT NULL DEFAULT 0,
    offered_count INT UNSIGNED NOT NULL DEFAULT 0,
    joined_count INT UNSIGNED NOT NULL DEFAULT 0,
    rejected_count INT UNSIGNED NOT NULL DEFAULT 0,
    average_match_score DECIMAL(5, 2) NOT NULL DEFAULT 0.00,
    average_days_to_hire DECIMAL(6, 2) NULL,
    updated_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6),
    CONSTRAINT pk_agg_monthly_hiring_funnel PRIMARY KEY (id),
    CONSTRAINT uq_agg_hiring_funnel UNIQUE (calendar_year, calendar_month, organisation_id, job_role_id),
    INDEX idx_agg_funnel_lookup (organisation_id, calendar_year, calendar_month)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;


-- 8. Gig Fulfilment KPI Aggregate Mart
CREATE TABLE IF NOT EXISTS agg_gig_fulfilment_kpi (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    calendar_year INT NOT NULL,
    calendar_month INT NOT NULL,
    city_id BIGINT UNSIGNED NOT NULL,
    total_gig_requests_count INT UNSIGNED NOT NULL DEFAULT 0,
    total_assignments_count INT UNSIGNED NOT NULL DEFAULT 0,
    total_fulfilled_gigs_count INT UNSIGNED NOT NULL DEFAULT 0,
    total_disputed_gigs_count INT UNSIGNED NOT NULL DEFAULT 0,
    total_payout_amount DECIMAL(14, 2) NOT NULL DEFAULT 0.00,
    average_gig_rating DECIMAL(3, 2) NOT NULL DEFAULT 0.00,
    fulfilment_rate_percentage DECIMAL(5, 2) NOT NULL DEFAULT 0.00,
    updated_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6),
    CONSTRAINT pk_agg_gig_fulfilment_kpi PRIMARY KEY (id),
    CONSTRAINT uq_agg_gig_kpi UNIQUE (calendar_year, calendar_month, city_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- ============================================================================
-- Tier 3: Reference Domains & Optional Stretch Coverage
-- ============================================================================

-- 9. Market Salary Benchmark Reference
CREATE TABLE IF NOT EXISTS salary_benchmark (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    uuid CHAR(36) NOT NULL DEFAULT (UUID()),
    job_role_id BIGINT UNSIGNED NOT NULL,
    experience_tier_code VARCHAR(50) NOT NULL,
    city_id BIGINT UNSIGNED NULL,
    percentile_25_salary DECIMAL(14, 2) NOT NULL,
    percentile_50_salary DECIMAL(14, 2) NOT NULL, -- Median salary
    percentile_75_salary DECIMAL(14, 2) NOT NULL,
    percentile_90_salary DECIMAL(14, 2) NOT NULL,
    currency_code CHAR(3) NOT NULL DEFAULT 'INR',
    sample_size_count INT UNSIGNED NOT NULL,
    data_source_provider VARCHAR(100) NOT NULL DEFAULT 'NORTHBRIDGE_AGGREGATE_V1',
    effective_year INT NOT NULL,
    effective_quarter INT NOT NULL,
    created_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    CONSTRAINT pk_salary_benchmark PRIMARY KEY (id),
    CONSTRAINT uq_salary_benchmark_uuid UNIQUE (uuid),
    CONSTRAINT uq_salary_benchmark_scope UNIQUE (job_role_id, experience_tier_code, city_id, effective_year, effective_quarter),
    CONSTRAINT fk_sb_role_id FOREIGN KEY (job_role_id) REFERENCES job_role (id) ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT fk_sb_city_id FOREIGN KEY (city_id) REFERENCES city (id) ON UPDATE CASCADE ON DELETE SET NULL,
    CONSTRAINT chk_sb_percentiles CHECK (percentile_90_salary >= percentile_75_salary AND percentile_75_salary >= percentile_50_salary AND percentile_50_salary >= percentile_25_salary)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- 10. Organisation Rating Snapshot
CREATE TABLE IF NOT EXISTS organisation_rating_snapshot (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    uuid CHAR(36) NOT NULL DEFAULT (UUID()),
    organisation_id BIGINT UNSIGNED NOT NULL,
    overall_rating_score DECIMAL(3, 2) NOT NULL,
    work_life_balance_score DECIMAL(3, 2) NOT NULL,
    culture_values_score DECIMAL(3, 2) NOT NULL,
    compensation_benefits_score DECIMAL(3, 2) NOT NULL,
    career_growth_score DECIMAL(3, 2) NOT NULL,
    reviews_count INT UNSIGNED NOT NULL DEFAULT 0,
    source_attribution_name VARCHAR(100) NOT NULL DEFAULT 'AMBITION_BENCHMARK',
    snapshot_date DATE NOT NULL,
    created_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    CONSTRAINT pk_organisation_rating_snapshot PRIMARY KEY (id),
    CONSTRAINT uq_organisation_rating_uuid UNIQUE (uuid),
    CONSTRAINT uq_org_rating_snapshot UNIQUE (organisation_id, snapshot_date),
    CONSTRAINT fk_ors_org_id FOREIGN KEY (organisation_id) REFERENCES organisation (id) ON UPDATE CASCADE ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- 11. Trending Job Skill Demand Snapshot
CREATE TABLE IF NOT EXISTS trending_job_snapshot (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    skill_id BIGINT UNSIGNED NOT NULL,
    job_role_id BIGINT UNSIGNED NOT NULL,
    snapshot_date DATE NOT NULL,
    active_postings_count INT UNSIGNED NOT NULL,
    candidate_demand_ratio DECIMAL(6, 2) NOT NULL,
    growth_rate_mom_percentage DECIMAL(5, 2) NOT NULL,
    created_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    CONSTRAINT pk_trending_job_snapshot PRIMARY KEY (id),
    CONSTRAINT uq_trending_job_metric UNIQUE (skill_id, job_role_id, snapshot_date),
    CONSTRAINT fk_tjs_skill_id FOREIGN KEY (skill_id) REFERENCES skill (id) ON UPDATE CASCADE ON DELETE CASCADE,
    CONSTRAINT fk_tjs_role_id FOREIGN KEY (job_role_id) REFERENCES job_role (id) ON UPDATE CASCADE ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- 12. Dynamic System Feature Flags
CREATE TABLE IF NOT EXISTS feature_flag (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    flag_key VARCHAR(100) NOT NULL,
    flag_description VARCHAR(255) NOT NULL,
    is_enabled_globally BOOLEAN NOT NULL DEFAULT FALSE,
    target_environment VARCHAR(50) NOT NULL DEFAULT 'PRODUCTION',
    rules_json JSON NULL, -- Specific organisation or user whitelists
    created_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    created_by BIGINT UNSIGNED NULL,
    updated_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6),
    updated_by BIGINT UNSIGNED NULL,
    CONSTRAINT pk_feature_flag PRIMARY KEY (id),
    CONSTRAINT uq_feature_flag_key UNIQUE (flag_key)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
