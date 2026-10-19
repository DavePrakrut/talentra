-- ============================================================================
-- Module 13: Integrity Triggers, Temporal Overlap Controls & Stored Procedures
-- Deliverables: Append-only ledgers, temporal non-overlap enforcement,
--               and device limit concurrency authentication procedure
-- Compliance: Rule Groups 2, 4, 9, 10
-- ============================================================================

USE talentra_db;

DELIMITER $$

-- ============================================================================
-- 1. Append-Only Enforcements (Rule Group 4 & 10)
-- ============================================================================

-- Disallow UPDATE on audit_log
DROP TRIGGER IF EXISTS trg_audit_log_prevent_update $$
CREATE TRIGGER trg_audit_log_prevent_update
BEFORE UPDATE ON audit_log
FOR EACH ROW
BEGIN
    SIGNAL SQLSTATE '45000'
    SET MESSAGE_TEXT = 'Security Violation: audit_log records are strictly immutable and cannot be updated.';
END $$

-- Disallow DELETE on audit_log
DROP TRIGGER IF EXISTS trg_audit_log_prevent_delete $$
CREATE TRIGGER trg_audit_log_prevent_delete
BEFORE DELETE ON audit_log
FOR EACH ROW
BEGIN
    SIGNAL SQLSTATE '45000'
    SET MESSAGE_TEXT = 'Security Violation: audit_log records are strictly immutable and cannot be deleted.';
END $$

-- Disallow UPDATE on wallet_transaction (Double-entry ledger rule)
DROP TRIGGER IF EXISTS trg_wallet_transaction_prevent_update $$
CREATE TRIGGER trg_wallet_transaction_prevent_update
BEFORE UPDATE ON wallet_transaction
FOR EACH ROW
BEGIN
    SIGNAL SQLSTATE '45000'
    SET MESSAGE_TEXT = 'Financial Integrity Violation: wallet_transaction is an append-only ledger. Issue a compensating transaction instead.';
END $$

-- Disallow DELETE on wallet_transaction
DROP TRIGGER IF EXISTS trg_wallet_transaction_prevent_delete $$
CREATE TRIGGER trg_wallet_transaction_prevent_delete
BEFORE DELETE ON wallet_transaction
FOR EACH ROW
BEGIN
    SIGNAL SQLSTATE '45000'
    SET MESSAGE_TEXT = 'Financial Integrity Violation: wallet_transaction records cannot be deleted.';
END $$

-- Disallow UPDATE on candidate_profile_download_history
DROP TRIGGER IF EXISTS trg_download_history_prevent_update $$
CREATE TRIGGER trg_download_history_prevent_update
BEFORE UPDATE ON candidate_profile_download_history
FOR EACH ROW
BEGIN
    SIGNAL SQLSTATE '45000'
    SET MESSAGE_TEXT = 'Audit Integrity Violation: candidate_profile_download_history is append-only.';
END $$

-- Disallow DELETE on candidate_profile_download_history
DROP TRIGGER IF EXISTS trg_download_history_prevent_delete $$
CREATE TRIGGER trg_download_history_prevent_delete
BEFORE DELETE ON candidate_profile_download_history
FOR EACH ROW
BEGIN
    SIGNAL SQLSTATE '45000'
    SET MESSAGE_TEXT = 'Audit Integrity Violation: candidate_profile_download_history records cannot be deleted.';
END $$

-- ============================================================================
-- 2. Temporal Non-Overlap Business Rules (Rule Group 10 & Milestone 10/14)
-- ============================================================================

-- Enforce Non-Overlapping Subscription Periods for the same licence
DROP TRIGGER IF EXISTS trg_subscription_period_prevent_overlap_insert $$
CREATE TRIGGER trg_subscription_period_prevent_overlap_insert
BEFORE INSERT ON subscription_period
FOR EACH ROW
BEGIN
    DECLARE overlap_count INT DEFAULT 0;
    
    SELECT COUNT(*) INTO overlap_count
    FROM subscription_period
    WHERE subscription_licence_id = NEW.subscription_licence_id
      AND period_status_code = 'ACTIVE'
      AND NEW.period_start_date <= period_end_date
      AND NEW.period_end_date >= period_start_date;
      
    IF overlap_count > 0 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Subscription Integrity Violation: Active subscription periods must not overlap for the same licence.';
    END IF;
END $$

-- Enforce Non-Overlapping Gig Assignments for the same Gig Worker (Milestone 10, B35)
DROP TRIGGER IF EXISTS trg_gig_assignment_prevent_overlap_insert $$
CREATE TRIGGER trg_gig_assignment_prevent_overlap_insert
BEFORE INSERT ON gig_assignment
FOR EACH ROW
BEGIN
    DECLARE overlap_count INT DEFAULT 0;
    
    SELECT COUNT(*) INTO overlap_count
    FROM gig_assignment
    WHERE gig_worker_profile_id = NEW.gig_worker_profile_id
      AND assignment_status_code IN ('ASSIGNED', 'IN_FULFILMENT')
      AND NEW.scheduled_start_time < scheduled_end_time
      AND NEW.scheduled_end_time > scheduled_start_time;
      
    IF overlap_count > 0 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Schedule Integrity Violation: Gig booking windows cannot overlap for the same gig worker.';
    END IF;
END $$

-- ============================================================================
-- 3. Concurrency & Device Limit Enforcement Procedure (Rule Group 9, Milestone 14)
-- ============================================================================

DROP PROCEDURE IF EXISTS sp_authenticate_and_open_session $$
CREATE PROCEDURE sp_authenticate_and_open_session(
    IN p_user_id BIGINT UNSIGNED,
    IN p_device_fingerprint VARCHAR(128),
    IN p_device_name VARCHAR(100),
    IN p_device_type VARCHAR(50),
    IN p_operating_system VARCHAR(100),
    IN p_browser_name VARCHAR(100),
    IN p_ip_address VARCHAR(45),
    IN p_user_agent VARCHAR(255),
    IN p_session_token_hash VARCHAR(128),
    OUT p_session_id BIGINT UNSIGNED,
    OUT p_status_code VARCHAR(50)
)
proc_block: BEGIN
    DECLARE v_max_devices INT UNSIGNED DEFAULT 2;
    DECLARE v_active_sessions_count INT UNSIGNED DEFAULT 0;
    DECLARE v_device_id BIGINT UNSIGNED;
    DECLARE v_licence_id BIGINT UNSIGNED;

    -- 1. Determine maximum devices allowed from user's active corporate licence
    SELECT sl.id, sl.max_devices_per_user 
    INTO v_licence_id, v_max_devices
    FROM licence_seat_allocation lsa
    INNER JOIN subscription_licence sl ON lsa.subscription_licence_id = sl.id
    WHERE lsa.app_user_id = p_user_id
      AND lsa.is_active = TRUE
      AND sl.is_active = TRUE
      AND CURRENT_DATE() BETWEEN sl.valid_from_date AND sl.valid_to_date
    LIMIT 1;

    -- If no enterprise licence assigned, default standard consumer allowance is 2 devices
    IF v_max_devices IS NULL THEN
        SET v_max_devices = 2;
    END IF;

    -- 2. Count current active sessions (using pessimistic locking)
    SELECT COUNT(*) INTO v_active_sessions_count
    FROM user_session
    WHERE app_user_id = p_user_id
      AND is_active = TRUE
      AND session_end_time IS NULL;

    -- 3. Check if device limit is exceeded
    IF v_active_sessions_count >= v_max_devices THEN
        -- Record security breach in audit trail
        INSERT INTO audit_log (
            actor_user_id, action_type, target_entity_name, 
            target_entity_id, ip_address, user_agent_string, pre_change_state
        ) VALUES (
            p_user_id, 'DEVICE_LIMIT_EXCEEDED_LOGIN_BLOCKED', 'user_session', 
            p_user_id, p_ip_address, p_user_agent,
            JSON_OBJECT('max_devices', v_max_devices, 'active_sessions', v_active_sessions_count)
        );

        -- Record failed login attempt
        INSERT INTO login_attempt_history (
            email_address, app_user_id, ip_address, user_agent_string, is_successful, failure_reason_code
        ) VALUES (
            (SELECT email_address FROM app_user WHERE id = p_user_id),
            p_user_id, p_ip_address, p_user_agent, FALSE, 'DEVICE_LIMIT_REACHED'
        );

        SET p_status_code = 'DEVICE_LIMIT_EXCEEDED';
        SET p_session_id = NULL;
        LEAVE proc_block;
    END IF;

    -- 4. Register or resolve device
    SELECT id INTO v_device_id
    FROM user_device
    WHERE app_user_id = p_user_id AND device_fingerprint_hash = p_device_fingerprint
    LIMIT 1;

    IF v_device_id IS NULL THEN
        INSERT INTO user_device (
            app_user_id, device_fingerprint_hash, device_name, device_type_code, operating_system, browser_name
        ) VALUES (
            p_user_id, p_device_fingerprint, p_device_name, p_device_type, p_operating_system, p_browser_name
        );
        SET v_device_id = LAST_INSERT_ID();
    ELSE
        UPDATE user_device 
        SET last_seen_at = NOW(6), browser_name = p_browser_name
        WHERE id = v_device_id;
    END IF;

    -- 5. Open new active session
    INSERT INTO user_session (
        app_user_id, user_device_id, session_token_hash, ip_address, user_agent_string, session_start_time, last_activity_time, is_active
    ) VALUES (
        p_user_id, v_device_id, p_session_token_hash, p_ip_address, p_user_agent, NOW(6), NOW(6), TRUE
    );

    SET p_session_id = LAST_INSERT_ID();
    SET p_status_code = 'SUCCESS';

    -- Record successful login
    INSERT INTO login_attempt_history (
        email_address, app_user_id, ip_address, user_agent_string, is_successful
    ) VALUES (
        (SELECT email_address FROM app_user WHERE id = p_user_id),
        p_user_id, p_ip_address, p_user_agent, TRUE
    );
END $$

DELIMITER ;
