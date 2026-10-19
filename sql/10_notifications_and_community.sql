-- ============================================================================
-- Module 10: Notifications, Preferences & Community
-- Deliverables: User preferences, high-volume delivery path, community forum,
--               support tickets, and platform FAQs
-- Compliance: Rule Groups 1, 2, 3, 4, 7, 8
-- ============================================================================

USE talentra_db;

-- 1. User Multi-Channel Preferences & Privacy Settings
CREATE TABLE IF NOT EXISTS user_preference (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    app_user_id BIGINT UNSIGNED NOT NULL,
    is_email_notification_enabled BOOLEAN NOT NULL DEFAULT TRUE,
    is_sms_notification_enabled BOOLEAN NOT NULL DEFAULT TRUE,
    is_push_notification_enabled BOOLEAN NOT NULL DEFAULT TRUE,
    is_whatsapp_notification_enabled BOOLEAN NOT NULL DEFAULT FALSE,
    is_marketing_newsletter_enabled BOOLEAN NOT NULL DEFAULT FALSE,
    job_alert_frequency_code VARCHAR(30) NOT NULL DEFAULT 'DAILY', -- 'INSTANT', 'DAILY', 'WEEKLY', 'OFF'
    profile_visibility_code VARCHAR(30) NOT NULL DEFAULT 'RECRUITERS_ONLY', -- 'PUBLIC', 'RECRUITERS_ONLY', 'ANONYMOUS', 'HIDDEN'
    preferred_ui_language_code CHAR(2) NOT NULL DEFAULT 'en',
    created_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    created_by BIGINT UNSIGNED NULL,
    updated_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6),
    updated_by BIGINT UNSIGNED NULL,
    CONSTRAINT pk_user_preference PRIMARY KEY (id),
    CONSTRAINT uq_user_preference_user UNIQUE (app_user_id),
    CONSTRAINT fk_up_user_id FOREIGN KEY (app_user_id) REFERENCES app_user (id) ON UPDATE CASCADE ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- 2. High-Volume Notification Delivery Outbox (Milestone 18 High-Volume Write Path)
CREATE TABLE IF NOT EXISTS notification_delivery (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    uuid CHAR(36) NOT NULL DEFAULT (UUID()),
    recipient_user_id BIGINT UNSIGNED NOT NULL,
    delivery_channel_code VARCHAR(30) NOT NULL, -- 'EMAIL', 'SMS', 'PUSH', 'WHATSAPP'
    notification_template_code VARCHAR(50) NOT NULL,
    idempotency_key VARCHAR(128) NOT NULL,
    notification_title VARCHAR(200) NOT NULL,
    payload_json JSON NOT NULL,
    delivery_status_code VARCHAR(30) NOT NULL DEFAULT 'QUEUED', -- 'QUEUED', 'SENT', 'DELIVERED', 'FAILED', 'BOUNCED'
    retry_count INT UNSIGNED NOT NULL DEFAULT 0,
    external_provider_message_id VARCHAR(100) NULL,
    failure_reason_summary VARCHAR(255) NULL,
    queued_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    sent_at DATETIME(6) NULL,
    delivered_at DATETIME(6) NULL,
    CONSTRAINT pk_notification_delivery PRIMARY KEY (id),
    CONSTRAINT uq_notification_delivery_uuid UNIQUE (uuid),
    CONSTRAINT uq_notification_idempotency UNIQUE (idempotency_key),
    CONSTRAINT fk_nd_user_id FOREIGN KEY (recipient_user_id) REFERENCES app_user (id) ON UPDATE CASCADE ON DELETE CASCADE,
    INDEX idx_nd_status_time (delivery_status_code, queued_at),
    INDEX idx_nd_recipient (recipient_user_id, queued_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;


-- 3. Community Forum Posts
CREATE TABLE IF NOT EXISTS community_post (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    uuid CHAR(36) NOT NULL DEFAULT (UUID()),
    author_user_id BIGINT UNSIGNED NOT NULL,
    post_category_code VARCHAR(50) NOT NULL DEFAULT 'CAREER_ADVICE', -- 'CAREER_ADVICE', 'SALARY_INSIGHTS', 'INTERVIEW_PREP', 'GIG_NETWORKING'
    post_title VARCHAR(200) NOT NULL,
    post_content TEXT NOT NULL,
    upvote_count INT UNSIGNED NOT NULL DEFAULT 0,
    comment_count INT UNSIGNED NOT NULL DEFAULT 0,
    is_moderated BOOLEAN NOT NULL DEFAULT FALSE,
    created_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    created_by BIGINT UNSIGNED NULL,
    updated_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6),
    updated_by BIGINT UNSIGNED NULL,
    deleted_at DATETIME(6) NULL,
    CONSTRAINT pk_community_post PRIMARY KEY (id),
    CONSTRAINT uq_community_post_uuid UNIQUE (uuid),
    CONSTRAINT fk_cpost_author_id FOREIGN KEY (author_user_id) REFERENCES app_user (id) ON UPDATE CASCADE ON DELETE RESTRICT,
    INDEX idx_cpost_category (post_category_code, created_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;


-- 4. Community Post Reactions
CREATE TABLE IF NOT EXISTS community_reaction (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    community_post_id BIGINT UNSIGNED NOT NULL,
    app_user_id BIGINT UNSIGNED NOT NULL,
    reaction_type_code VARCHAR(30) NOT NULL DEFAULT 'LIKE', -- 'LIKE', 'HELPFUL', 'INSIGHTFUL'
    created_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    CONSTRAINT pk_community_reaction PRIMARY KEY (id),
    CONSTRAINT uq_post_user_reaction UNIQUE (community_post_id, app_user_id, reaction_type_code),
    CONSTRAINT fk_cr_post_id FOREIGN KEY (community_post_id) REFERENCES community_post (id) ON UPDATE CASCADE ON DELETE CASCADE,
    CONSTRAINT fk_cr_user_id FOREIGN KEY (app_user_id) REFERENCES app_user (id) ON UPDATE CASCADE ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- 5. Helpdesk Support Tickets
CREATE TABLE IF NOT EXISTS support_ticket (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    uuid CHAR(36) NOT NULL DEFAULT (UUID()),
    ticket_reference_number VARCHAR(50) NOT NULL,
    requester_user_id BIGINT UNSIGNED NOT NULL,
    assigned_admin_user_id BIGINT UNSIGNED NULL,
    ticket_category_code VARCHAR(50) NOT NULL, -- 'BILLING', 'ACCOUNT_ACCESS', 'GIG_DISPUTE', 'REPORT_ABUSE'
    priority_level_code VARCHAR(20) NOT NULL DEFAULT 'MEDIUM', -- 'LOW', 'MEDIUM', 'HIGH', 'CRITICAL'
    ticket_status_code VARCHAR(30) NOT NULL DEFAULT 'OPEN', -- 'OPEN', 'IN_INVESTIGATION', 'RESOLVED', 'CLOSED'
    subject_title VARCHAR(200) NOT NULL,
    issue_description TEXT NOT NULL,
    resolution_summary TEXT NULL,
    resolved_at DATETIME(6) NULL,
    created_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    created_by BIGINT UNSIGNED NULL,
    updated_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6),
    updated_by BIGINT UNSIGNED NULL,
    CONSTRAINT pk_support_ticket PRIMARY KEY (id),
    CONSTRAINT uq_support_ticket_uuid UNIQUE (uuid),
    CONSTRAINT uq_support_ticket_ref UNIQUE (ticket_reference_number),
    CONSTRAINT fk_st_requester_id FOREIGN KEY (requester_user_id) REFERENCES app_user (id) ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT fk_st_assigned_admin_id FOREIGN KEY (assigned_admin_user_id) REFERENCES app_user (id) ON UPDATE CASCADE ON DELETE SET NULL,
    INDEX idx_st_status_priority (ticket_status_code, priority_level_code)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;


-- 6. Platform Frequently Asked Questions (FAQs)
CREATE TABLE IF NOT EXISTS platform_faq (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    uuid CHAR(36) NOT NULL DEFAULT (UUID()),
    faq_category_code VARCHAR(50) NOT NULL, -- 'CANDIDATE_GUIDE', 'EMPLOYER_BILLING', 'GIG_RULES'
    question_text VARCHAR(255) NOT NULL,
    answer_html TEXT NOT NULL,
    is_published BOOLEAN NOT NULL DEFAULT TRUE,
    display_order INT NOT NULL DEFAULT 0,
    created_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    created_by BIGINT UNSIGNED NULL,
    updated_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6),
    updated_by BIGINT UNSIGNED NULL,
    CONSTRAINT pk_platform_faq PRIMARY KEY (id),
    CONSTRAINT uq_platform_faq_uuid UNIQUE (uuid),
    INDEX idx_faq_category (faq_category_code, display_order)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

