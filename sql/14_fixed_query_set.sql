-- ============================================================================
-- Module 14: Fixed Query Set (12 Core Workflows & Performance Benchmark)
-- Deliverables: 12 production queries covering functional, transactional,
--               lookup, security, and analytical performance cases
-- Docket Reference: Milestone 20 (Backlog B65) & Milestone 21 (Backlog B70)
-- ============================================================================

USE talentra_db;

-- ============================================================================
-- Query 1: Candidate Search with Dynamic Privacy Blocking (Functional / Security)
-- Sourcing candidates by job role, city, and min experience, guaranteeing that
-- candidates who blocked the viewing employer/recruiter are strictly excluded.
-- ============================================================================
-- EXPLAIN ANALYZE
SELECT 
    cp.id AS candidate_profile_id,
    cp.uuid AS candidate_uuid,
    cp.display_name,
    c.city_name,
    jr.role_name,
    cp.total_experience_months,
    cp.profile_completion_percentage,
    cp.notice_period_days,
    cp.expected_salary,
    cp.salary_currency_code
FROM candidate_profile cp
INNER JOIN app_user u ON cp.app_user_id = u.id
LEFT JOIN city c ON cp.current_city_id = c.id
LEFT JOIN job_role jr ON cp.current_job_role_id = jr.id
WHERE cp.deleted_at IS NULL
  AND cp.is_actively_looking = TRUE
  AND cp.current_job_role_id = 1 -- E.g. Full Stack Developer
  AND cp.total_experience_months >= 24 -- 2+ years experience
  -- Privacy Blocking Rule: Candidate must not have blocked Organisation #1 or Recruiter User #10
  AND NOT EXISTS (
      SELECT 1 
      FROM privacy_block_entry pbe
      WHERE pbe.blocker_candidate_user_id = u.id
        AND pbe.is_active = TRUE
        AND (
            (pbe.blocked_entity_type = 'ORGANISATION' AND pbe.blocked_target_id = 1) OR
            (pbe.blocked_entity_type = 'RECRUITER_USER' AND pbe.blocked_target_id = 10)
        )
  )
ORDER BY cp.profile_completion_percentage DESC, cp.total_experience_months DESC
LIMIT 50;

-- ============================================================================
-- Query 2: Employer Hiring Pipeline Funnel Breakdown (Transactional / Pipeline)
-- Aggregates application pipeline counts across stages for an active requisition.
-- ============================================================================
-- EXPLAIN ANALYZE
SELECT 
    ja.job_requirement_id,
    jr.job_title,
    o.trade_name AS company_name,
    COUNT(ja.id) AS total_applicants,
    SUM(CASE WHEN ja.application_status_code = 'APPLIED' THEN 1 ELSE 0 END) AS count_applied,
    SUM(CASE WHEN ja.application_status_code = 'SHORTLISTED' THEN 1 ELSE 0 END) AS count_shortlisted,
    SUM(CASE WHEN ja.application_status_code = 'INTERVIEWED' THEN 1 ELSE 0 END) AS count_interviewed,
    SUM(CASE WHEN ja.application_status_code = 'OFFERED' THEN 1 ELSE 0 END) AS count_offered,
    SUM(CASE WHEN ja.application_status_code = 'JOINED' THEN 1 ELSE 0 END) AS count_joined,
    SUM(CASE WHEN ja.application_status_code = 'REJECTED' THEN 1 ELSE 0 END) AS count_rejected,
    ROUND(AVG(ja.match_score_percentage), 2) AS average_match_score
FROM job_application ja
INNER JOIN job_requirement jr ON ja.job_requirement_id = jr.id
INNER JOIN organisation o ON jr.organisation_id = o.id
WHERE jr.organisation_id = 1
  AND jr.publish_state_code = 'PUBLISHED'
GROUP BY ja.job_requirement_id, jr.job_title, o.trade_name;

-- ============================================================================
-- Query 3: Multi-Skill Candidate Matching Algorithm (Complex Join / Scoring)
-- Finds candidates possessing required skills for a job requisition, computing
-- exact skill overlap percentage and prioritizing verified skills.
-- ============================================================================
-- EXPLAIN ANALYZE
SELECT 
    cp.id AS candidate_profile_id,
    cp.display_name,
    u.email_address,
    COUNT(jrs.skill_id) AS matched_skills_count,
    ROUND((COUNT(jrs.skill_id) / 
          (SELECT COUNT(*) FROM job_requirement_skill WHERE job_requirement_id = 1)
         ) * 100.0, 2) AS skill_match_percentage,
    SUM(CASE WHEN cs.is_verified_by_test = TRUE THEN 1 ELSE 0 END) AS verified_skills_count
FROM candidate_profile cp
INNER JOIN app_user u ON cp.app_user_id = u.id
INNER JOIN candidate_skill cs ON cs.candidate_profile_id = cp.id
INNER JOIN job_requirement_skill jrs ON jrs.skill_id = cs.skill_id
WHERE jrs.job_requirement_id = 1 -- Target job requisition
  AND cp.deleted_at IS NULL
GROUP BY cp.id, cp.display_name, u.email_address
HAVING matched_skills_count >= 1
ORDER BY skill_match_percentage DESC, verified_skills_count DESC
LIMIT 25;

-- ============================================================================
-- Query 4: Available Gig Worker Discovery (Spatial / Temporal Lookup)
-- Identifies unbooked gig workers matching hourly rate, city, and time window,
-- excluding any workers blacklisted by the requesting employer.
-- ============================================================================
-- EXPLAIN ANALYZE
SELECT 
    gwp.id AS gig_worker_profile_id,
    u.id AS worker_user_id,
    gwp.headline,
    gwp.hourly_charge_rate,
    gwp.overall_rating_average,
    gwp.completed_gigs_count,
    ga.available_start_time,
    ga.available_end_time
FROM gig_worker_profile gwp
INNER JOIN app_user u ON gwp.app_user_id = u.id
INNER JOIN candidate_profile cp ON cp.app_user_id = u.id
INNER JOIN gig_availability ga ON ga.gig_worker_profile_id = gwp.id
WHERE ga.is_booked = FALSE
  AND ga.available_start_time <= '2026-10-16 09:00:00'
  AND ga.available_end_time >= '2026-10-16 18:00:00'
  AND gwp.hourly_charge_rate <= 1500.00
  AND cp.current_city_id = 1 -- Bengaluru
  -- Exclude blacklisted workers for Organisation #1
  AND NOT EXISTS (
      SELECT 1 
      FROM gig_blacklist_worker gbw
      WHERE gbw.organisation_id = 1
        AND gbw.gig_worker_profile_id = gwp.id
  )
ORDER BY gwp.overall_rating_average DESC, gwp.completed_gigs_count DESC
LIMIT 20;

-- ============================================================================
-- Query 5: Active Device & Session Limit Concurrency Enforcement Check
-- Evaluates a user's active session count against corporate licence max devices.
-- ============================================================================
-- EXPLAIN ANALYZE
SELECT 
    u.id AS user_id,
    u.email_address,
    COALESCE(sl.max_devices_per_user, 2) AS allowed_max_devices,
    COUNT(us.id) AS current_active_sessions_count,
    CASE 
        WHEN COUNT(us.id) >= COALESCE(sl.max_devices_per_user, 2) THEN 'DEVICE_QUOTA_REACHED'
        ELSE 'LOGIN_PERMITTED'
    END AS admission_status
FROM app_user u
LEFT JOIN licence_seat_allocation lsa ON lsa.app_user_id = u.id AND lsa.is_active = TRUE
LEFT JOIN subscription_licence sl ON lsa.subscription_licence_id = sl.id 
     AND sl.is_active = TRUE 
     AND CURRENT_DATE() BETWEEN sl.valid_from_date AND sl.valid_to_date
LEFT JOIN user_session us ON us.app_user_id = u.id 
     AND us.is_active = TRUE 
     AND us.session_end_time IS NULL
WHERE u.id = 2 -- Sample target user
GROUP BY u.id, u.email_address, sl.max_devices_per_user;

-- ============================================================================
-- Query 6: Recruiter-Scoped Requisition Discovery (Tenant Isolation)
-- "A recruiter may only see and act on job requirements assigned to their own company."
-- ============================================================================
-- EXPLAIN ANALYZE
SELECT 
    jr.id AS job_requirement_id,
    jr.uuid AS job_uuid,
    o.legal_name AS company_legal_name,
    jr.job_title,
    jr.positions_count,
    jr.positions_filled_count,
    jr.publish_state_code,
    jr.open_date,
    COUNT(ja.id) AS total_applications_received
FROM recruiter_assignment ra
INNER JOIN organisation o ON ra.organisation_id = o.id
INNER JOIN job_requirement jr ON jr.organisation_id = o.id
LEFT JOIN job_application ja ON ja.job_requirement_id = jr.id
WHERE ra.recruiter_user_id = 3 -- Target Recruiter User
  AND ra.is_active = TRUE
  AND (ra.effective_to_date IS NULL OR ra.effective_to_date >= CURRENT_DATE())
  AND jr.deleted_at IS NULL
GROUP BY jr.id, jr.uuid, o.legal_name, jr.job_title, jr.positions_count, 
         jr.positions_filled_count, jr.publish_state_code, jr.open_date
ORDER BY jr.open_date DESC;

-- ============================================================================
-- Query 7: Append-Only Wallet Ledger Balance Audit & Reconciliation
-- Calculates current wallet balance from raw append-only ledger entries and
-- compares it with cached balance to ensure zero double-spend or drift.
-- ============================================================================
-- EXPLAIN ANALYZE
SELECT 
    wa.id AS wallet_account_id,
    wa.organisation_id,
    wa.current_credit_balance AS cached_balance,
    COALESCE(SUM(wt.transaction_amount), 0.00) AS computed_ledger_balance,
    ROUND(wa.current_credit_balance - COALESCE(SUM(wt.transaction_amount), 0.00), 2) AS reconciliation_drift,
    COUNT(wt.id) AS total_ledger_transactions_count
FROM wallet_account wa
LEFT JOIN wallet_transaction wt ON wt.wallet_account_id = wa.id
WHERE wa.organisation_id = 1
GROUP BY wa.id, wa.organisation_id, wa.current_credit_balance;

-- ============================================================================
-- Query 8: Gig External Fulfilment Reconciliation Status (Boundary 4)
-- Monitors pending external fulfilment handoffs requiring status sync or payout.
-- ============================================================================
-- EXPLAIN ANALYZE
SELECT 
    ga.id AS gig_assignment_id,
    ga.external_handoff_reference_id,
    ga.assignment_status_code,
    ga.scheduled_start_time,
    ga.scheduled_end_time,
    ger.estimated_earnings,
    ger.reconciled_earnings,
    ger.reconciliation_status_code,
    TIMESTAMPDIFF(HOUR, ga.scheduled_end_time, NOW(6)) AS hours_elapsed_since_completion
FROM gig_assignment ga
INNER JOIN gig_earnings_reference ger ON ger.gig_assignment_id = ga.id
WHERE ga.assignment_status_code = 'FULFILLED'
  AND ger.reconciliation_status_code = 'PENDING_RECONCILIATION'
ORDER BY ga.scheduled_end_time ASC
LIMIT 50;

-- ============================================================================
-- Query 9: High-Volume Notification Delivery Outbox Polling (Write/Read Path)
-- Fetches queued notifications for dispatch with optimistic status locking.
-- ============================================================================
-- EXPLAIN ANALYZE
SELECT 
    nd.id AS notification_delivery_id,
    nd.recipient_user_id,
    u.email_address,
    CONCAT(u.country_dial_code, u.national_phone_number) AS phone_e164,
    nd.delivery_channel_code,
    nd.notification_template_code,
    nd.notification_title,
    nd.payload_json,
    nd.retry_count
FROM notification_delivery nd
INNER JOIN app_user u ON nd.recipient_user_id = u.id
WHERE nd.delivery_status_code = 'QUEUED'
  AND nd.retry_count < 3
ORDER BY nd.queued_at ASC
LIMIT 100;

-- ============================================================================
-- Query 10: Monthly Hiring Funnel & Time-to-Hire Analytics (Dimensional KPI)
-- Analyzes conversion drop-offs from application to offer across departments.
-- ============================================================================
-- EXPLAIN ANALYZE
SELECT 
    dt.calendar_year,
    dt.calendar_month,
    dj.industry_name,
    dj.job_role_name,
    SUM(fae.is_applied) AS total_applied,
    SUM(fae.is_shortlisted) AS total_shortlisted,
    SUM(fae.is_interviewed) AS total_interviewed,
    SUM(fae.is_offered) AS total_offered,
    SUM(fae.is_joined) AS total_joined,
    ROUND((SUM(fae.is_joined) / NULLIF(SUM(fae.is_applied), 0)) * 100.0, 2) AS overall_conversion_percentage,
    ROUND(AVG(fae.days_to_offer), 1) AS average_days_to_offer
FROM fact_application_event fae
INNER JOIN dim_time dt ON fae.dim_time_id = dt.id
INNER JOIN dim_job dj ON fae.dim_job_id = dj.id
WHERE dt.calendar_year = 2026
GROUP BY dt.calendar_year, dt.calendar_month, dj.industry_name, dj.job_role_name
ORDER BY dt.calendar_month DESC, total_applied DESC;

-- ============================================================================
-- Query 11: Candidate Profile Download Audit History (Commercial Tracking)
-- Audits which recruiter downloaded which candidate profile and credits spent.
-- ============================================================================
-- EXPLAIN ANALYZE
SELECT 
    cpdh.id AS download_audit_id,
    o.trade_name AS downloading_company,
    u.email_address AS recruiter_email,
    cp.display_name AS candidate_name,
    cpdh.credit_deduction_amount,
    cpdh.download_purpose,
    cpdh.downloaded_at,
    cpdh.ip_address
FROM candidate_profile_download_history cpdh
INNER JOIN organisation o ON cpdh.downloader_organisation_id = o.id
INNER JOIN app_user u ON cpdh.downloader_user_id = u.id
INNER JOIN candidate_profile cp ON cpdh.candidate_profile_id = cp.id
WHERE cpdh.downloader_organisation_id = 1
ORDER BY cpdh.downloaded_at DESC
LIMIT 50;

-- ============================================================================
-- Query 12: Salary Percentile Benchmark Comparison (Market Intelligence Tier 3)
-- Compares candidate expected salary against market percentiles (p25, p50, p75).
-- ============================================================================
-- EXPLAIN ANALYZE
SELECT 
    cp.id AS candidate_profile_id,
    cp.display_name,
    jr.role_name,
    c.city_name,
    cp.expected_salary AS candidate_expected_salary,
    sb.percentile_25_salary AS market_p25,
    sb.percentile_50_salary AS market_median_p50,
    sb.percentile_75_salary AS market_p75,
    sb.percentile_90_salary AS market_p90,
    CASE 
        WHEN cp.expected_salary < sb.percentile_25_salary THEN 'BELOW_MARKET'
        WHEN cp.expected_salary BETWEEN sb.percentile_25_salary AND sb.percentile_75_salary THEN 'MARKET_ALIGNED'
        ELSE 'ABOVE_MARKET'
    END AS market_competitiveness_band
FROM candidate_profile cp
INNER JOIN job_role jr ON cp.current_job_role_id = jr.id
LEFT JOIN city c ON cp.current_city_id = c.id
LEFT JOIN salary_benchmark sb ON sb.job_role_id = cp.current_job_role_id 
     AND (sb.city_id = cp.current_city_id OR sb.city_id IS NULL)
     AND sb.effective_year = 2026
WHERE cp.deleted_at IS NULL
  AND cp.expected_salary IS NOT NULL
LIMIT 50;
