-- ============================================================================
-- Module 9: Subscriptions, Wallet, Payments & Download History
-- Deliverables: Plans, non-overlapping periods, append-only wallet ledger,
--               payment orders, invoices, refunds, profile download audits
-- Compliance: Rule Groups 1, 2, 3, 4, 10
-- ============================================================================

USE talentra_db;

-- 1. Subscription Commercial Plan
CREATE TABLE IF NOT EXISTS subscription_plan (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    uuid CHAR(36) NOT NULL DEFAULT (UUID()),
    plan_code VARCHAR(50) NOT NULL,
    plan_name VARCHAR(100) NOT NULL,
    billing_interval_code VARCHAR(30) NOT NULL DEFAULT 'MONTHLY', -- 'MONTHLY', 'QUARTERLY', 'ANNUAL'
    price_amount DECIMAL(14, 2) NOT NULL,
    currency_code CHAR(3) NOT NULL DEFAULT 'INR',
    included_job_postings_count INT UNSIGNED NOT NULL DEFAULT 10,
    included_profile_downloads_count INT UNSIGNED NOT NULL DEFAULT 50,
    included_outreach_credits INT UNSIGNED NOT NULL DEFAULT 200,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    created_by BIGINT UNSIGNED NULL,
    updated_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6),
    updated_by BIGINT UNSIGNED NULL,
    deleted_at DATETIME(6) NULL,
    CONSTRAINT pk_subscription_plan PRIMARY KEY (id),
    CONSTRAINT uq_subscription_plan_uuid UNIQUE (uuid),
    CONSTRAINT uq_subscription_plan_code UNIQUE (plan_code),
    CONSTRAINT chk_sp_price CHECK (price_amount >= 0.00)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- 2. Non-Overlapping Subscription Period for Licences (Rule Group 10)
CREATE TABLE IF NOT EXISTS subscription_period (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    uuid CHAR(36) NOT NULL DEFAULT (UUID()),
    subscription_licence_id BIGINT UNSIGNED NOT NULL,
    subscription_plan_id BIGINT UNSIGNED NOT NULL,
    period_start_date DATE NOT NULL,
    period_end_date DATE NOT NULL,
    period_status_code VARCHAR(50) NOT NULL DEFAULT 'ACTIVE', -- 'ACTIVE', 'RENEWED', 'CANCELLED', 'EXPIRED'
    is_auto_renew_enabled BOOLEAN NOT NULL DEFAULT TRUE,
    created_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    created_by BIGINT UNSIGNED NULL,
    updated_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6),
    updated_by BIGINT UNSIGNED NULL,
    CONSTRAINT pk_subscription_period PRIMARY KEY (id),
    CONSTRAINT uq_subscription_period_uuid UNIQUE (uuid),
    CONSTRAINT fk_speriod_licence_id FOREIGN KEY (subscription_licence_id) REFERENCES subscription_licence (id) ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT fk_speriod_plan_id FOREIGN KEY (subscription_plan_id) REFERENCES subscription_plan (id) ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT chk_speriod_dates CHECK (period_end_date >= period_start_date),
    INDEX idx_speriod_licence (subscription_licence_id, period_start_date, period_end_date)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;


-- 3. Commercial Wallet Account (Per Organization or Individual Recruiter)
CREATE TABLE IF NOT EXISTS wallet_account (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    uuid CHAR(36) NOT NULL DEFAULT (UUID()),
    organisation_id BIGINT UNSIGNED NOT NULL,
    current_credit_balance DECIMAL(14, 2) NOT NULL DEFAULT 0.00,
    currency_code CHAR(3) NOT NULL DEFAULT 'INR',
    wallet_status_code VARCHAR(50) NOT NULL DEFAULT 'ACTIVE', -- 'ACTIVE', 'FROZEN', 'CLOSED'
    created_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    created_by BIGINT UNSIGNED NULL,
    updated_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6),
    updated_by BIGINT UNSIGNED NULL,
    CONSTRAINT pk_wallet_account PRIMARY KEY (id),
    CONSTRAINT uq_wallet_account_uuid UNIQUE (uuid),
    CONSTRAINT uq_wallet_organisation UNIQUE (organisation_id),
    CONSTRAINT fk_wa_organisation_id FOREIGN KEY (organisation_id) REFERENCES organisation (id) ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT chk_wa_balance CHECK (current_credit_balance >= 0.00)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- 4. Payment Order (Gateway Boundary 1)
CREATE TABLE IF NOT EXISTS payment_order (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    uuid CHAR(36) NOT NULL DEFAULT (UUID()),
    organisation_id BIGINT UNSIGNED NOT NULL,
    initiated_by_user_id BIGINT UNSIGNED NOT NULL,
    idempotency_key VARCHAR(128) NOT NULL,
    order_amount DECIMAL(14, 2) NOT NULL,
    currency_code CHAR(3) NOT NULL DEFAULT 'INR',
    order_purpose_code VARCHAR(50) NOT NULL, -- 'WALLET_RECHARGE', 'PLAN_PURCHASE', 'PLAN_RENEWAL'
    gateway_provider_name VARCHAR(50) NOT NULL DEFAULT 'STRIPE', -- 'STRIPE', 'RAZORPAY', 'ADYEN'
    gateway_order_reference_id VARCHAR(100) NULL,
    payment_status_code VARCHAR(50) NOT NULL DEFAULT 'PENDING', -- 'PENDING', 'AUTHORIZED', 'CAPTURED', 'FAILED', 'REFUNDED'
    paid_at DATETIME(6) NULL,
    created_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    created_by BIGINT UNSIGNED NULL,
    updated_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6),
    updated_by BIGINT UNSIGNED NULL,
    CONSTRAINT pk_payment_order PRIMARY KEY (id),
    CONSTRAINT uq_payment_order_uuid UNIQUE (uuid),
    CONSTRAINT uq_payment_order_idempotency UNIQUE (idempotency_key),
    CONSTRAINT fk_po_organisation_id FOREIGN KEY (organisation_id) REFERENCES organisation (id) ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT fk_po_user_id FOREIGN KEY (initiated_by_user_id) REFERENCES app_user (id) ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT chk_po_amount CHECK (order_amount > 0.00),
    INDEX idx_po_gateway_ref (gateway_provider_name, gateway_order_reference_id),
    INDEX idx_po_org_time (organisation_id, created_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;


-- 5. Append-Only Double-Entry Wallet Ledger (Rule Group 10)
CREATE TABLE IF NOT EXISTS wallet_transaction (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    uuid CHAR(36) NOT NULL DEFAULT (UUID()),
    wallet_account_id BIGINT UNSIGNED NOT NULL,
    transaction_type_code VARCHAR(50) NOT NULL, -- 'CREDIT_RECHARGE', 'DEBIT_JOB_POSTING', 'DEBIT_PROFILE_DOWNLOAD', 'DEBIT_OUTREACH', 'REFUND_CORRECTION'
    transaction_amount DECIMAL(14, 2) NOT NULL, -- Positive for credit, negative for debit
    balance_after_transaction DECIMAL(14, 2) NOT NULL,
    currency_code CHAR(3) NOT NULL DEFAULT 'INR',
    payment_order_id BIGINT UNSIGNED NULL, -- Populated on recharge
    original_compensating_transaction_id BIGINT UNSIGNED NULL, -- Self-reference for corrections
    transaction_description VARCHAR(255) NOT NULL,
    transaction_timestamp DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    CONSTRAINT pk_wallet_transaction PRIMARY KEY (id),
    CONSTRAINT uq_wallet_transaction_uuid UNIQUE (uuid),
    CONSTRAINT fk_wt_wallet_id FOREIGN KEY (wallet_account_id) REFERENCES wallet_account (id) ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT fk_wt_payment_order_id FOREIGN KEY (payment_order_id) REFERENCES payment_order (id) ON UPDATE CASCADE ON DELETE SET NULL,
    CONSTRAINT fk_wt_correction_id FOREIGN KEY (original_compensating_transaction_id) REFERENCES wallet_transaction (id) ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT chk_wt_balance_after CHECK (balance_after_transaction >= 0.00),
    INDEX idx_wt_wallet_time (wallet_account_id, transaction_timestamp)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;


-- 6. Official Tax Invoices
CREATE TABLE IF NOT EXISTS invoice_record (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    uuid CHAR(36) NOT NULL DEFAULT (UUID()),
    payment_order_id BIGINT UNSIGNED NOT NULL,
    invoice_number VARCHAR(100) NOT NULL,
    subtotal_amount DECIMAL(14, 2) NOT NULL,
    tax_amount DECIMAL(14, 2) NOT NULL DEFAULT 0.00,
    total_amount DECIMAL(14, 2) NOT NULL,
    currency_code CHAR(3) NOT NULL DEFAULT 'INR',
    invoice_pdf_uri VARCHAR(500) NULL,
    issued_date DATE NOT NULL,
    created_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    CONSTRAINT pk_invoice_record PRIMARY KEY (id),
    CONSTRAINT uq_invoice_record_uuid UNIQUE (uuid),
    CONSTRAINT uq_invoice_number UNIQUE (invoice_number),
    CONSTRAINT uq_invoice_order UNIQUE (payment_order_id),
    CONSTRAINT fk_ir_order_id FOREIGN KEY (payment_order_id) REFERENCES payment_order (id) ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT chk_ir_total CHECK (total_amount = subtotal_amount + tax_amount)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- 7. Payment Refund Records
CREATE TABLE IF NOT EXISTS refund_record (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    uuid CHAR(36) NOT NULL DEFAULT (UUID()),
    payment_order_id BIGINT UNSIGNED NOT NULL,
    refund_amount DECIMAL(14, 2) NOT NULL,
    currency_code CHAR(3) NOT NULL DEFAULT 'INR',
    refund_reason VARCHAR(255) NOT NULL,
    gateway_refund_reference_id VARCHAR(100) NOT NULL,
    refund_status_code VARCHAR(50) NOT NULL DEFAULT 'PROCESSED',
    processed_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    created_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    CONSTRAINT pk_refund_record PRIMARY KEY (id),
    CONSTRAINT uq_refund_record_uuid UNIQUE (uuid),
    CONSTRAINT fk_rr_order_id FOREIGN KEY (payment_order_id) REFERENCES payment_order (id) ON UPDATE CASCADE ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- 8. Append-Only Profile Download Audit History (Rule Group 10)
-- "which recruiter or employer downloaded which candidate profile, when, and under which credit deduction"
CREATE TABLE IF NOT EXISTS candidate_profile_download_history (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    downloader_user_id BIGINT UNSIGNED NOT NULL,
    downloader_organisation_id BIGINT UNSIGNED NOT NULL,
    candidate_profile_id BIGINT UNSIGNED NOT NULL,
    candidate_resume_id BIGINT UNSIGNED NOT NULL,
    credit_deduction_amount DECIMAL(10, 2) NOT NULL DEFAULT 1.00,
    download_purpose VARCHAR(100) NOT NULL DEFAULT 'DIRECT_SOURCING',
    ip_address VARCHAR(45) NOT NULL,
    downloaded_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    CONSTRAINT pk_candidate_profile_download_history PRIMARY KEY (id),
    CONSTRAINT fk_cpdh_user_id FOREIGN KEY (downloader_user_id) REFERENCES app_user (id) ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT fk_cpdh_org_id FOREIGN KEY (downloader_organisation_id) REFERENCES organisation (id) ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT fk_cpdh_candidate_id FOREIGN KEY (candidate_profile_id) REFERENCES candidate_profile (id) ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT fk_cpdh_resume_id FOREIGN KEY (candidate_resume_id) REFERENCES candidate_resume (id) ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT chk_cpdh_credits CHECK (credit_deduction_amount >= 0.00),
    INDEX idx_cpdh_downloader (downloader_organisation_id, downloaded_at),
    INDEX idx_cpdh_candidate (candidate_profile_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

