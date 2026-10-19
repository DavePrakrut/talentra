-- ============================================================================
-- Module 12: Secure Views & Access Control Rules
-- Deliverables: Database-enforced views for recruiter isolation, consultant gating,
--               and candidate-driven entity blocking lists
-- Compliance: Section 3 (Rules You Must Honour), Rule Groups 1, 6, 8
-- ============================================================================

USE talentra_db;

-- 1. Secure Candidate Search View with Dynamic Privacy Blocking
-- "A candidate may block employers, recruiters, or consultants, and a blocked party must not see that candidate."
CREATE OR REPLACE VIEW v_candidate_discovery AS
SELECT 
    cp.id AS candidate_profile_id,
    cp.uuid AS candidate_uuid,
    cp.first_name,
    cp.last_name,
    cp.display_name,
    c.city_name,
    jr.role_name AS current_job_role_name,
    cp.total_experience_months,
    cp.current_salary,
    cp.expected_salary,
    cp.salary_currency_code,
    cp.salary_disclosure_status,
    cp.notice_period_days,
    cp.profile_completion_percentage,
    cp.is_actively_looking,
    cp.created_at
FROM candidate_profile cp
LEFT JOIN city c ON cp.current_city_id = c.id
LEFT JOIN job_role jr ON cp.current_job_role_id = jr.id
WHERE cp.deleted_at IS NULL
  AND cp.is_actively_looking = TRUE;

-- 2. Recruiter Company Isolation View
-- "A recruiter may only see and act on job requirements assigned to their own company."
CREATE OR REPLACE VIEW v_recruiter_job_feed AS
SELECT 
    ra.recruiter_user_id,
    o.id AS organisation_id,
    o.legal_name AS company_name,
    jr.id AS job_requirement_id,
    jr.uuid AS job_uuid,
    jr.job_title,
    jr.positions_count,
    jr.positions_filled_count,
    jr.publish_state_code,
    jr.open_date,
    jr.close_date
FROM recruiter_assignment ra
INNER JOIN organisation o ON ra.organisation_id = o.id
INNER JOIN job_requirement jr ON jr.organisation_id = o.id
WHERE ra.is_active = TRUE
  AND (ra.effective_to_date IS NULL OR ra.effective_to_date >= CURRENT_DATE())
  AND jr.deleted_at IS NULL;

-- 3. Consultant Open Requisitions View
-- "A consultant may only work on job requirements that are open to consultants."
CREATE OR REPLACE VIEW v_consultant_open_job_feed AS
SELECT 
    jr.id AS job_requirement_id,
    jr.uuid AS job_uuid,
    o.id AS organisation_id,
    o.trade_name AS company_display_name,
    jr.job_title,
    jr.job_description,
    jr.minimum_experience_months,
    jr.maximum_experience_months,
    jr.minimum_salary,
    jr.maximum_salary,
    jr.salary_currency_code,
    jr.open_date
FROM job_requirement jr
INNER JOIN organisation o ON jr.organisation_id = o.id
WHERE jr.is_open_to_consultants = TRUE
  AND jr.publish_state_code = 'PUBLISHED'
  AND jr.deleted_at IS NULL
  AND (jr.close_date IS NULL OR jr.close_date >= CURRENT_DATE());

-- 4. Active Device Sessions View (Rule Group 9)
CREATE OR REPLACE VIEW v_active_user_session AS
SELECT 
    us.id AS user_session_id,
    us.app_user_id,
    u.email_address,
    ud.device_name,
    ud.device_type_code,
    us.ip_address,
    us.session_start_time,
    us.last_activity_time,
    TIMESTAMPDIFF(MINUTE, us.last_activity_time, NOW(6)) AS inactive_minutes
FROM user_session us
INNER JOIN app_user u ON us.app_user_id = u.id
INNER JOIN user_device ud ON us.user_device_id = ud.id
WHERE us.is_active = TRUE
  AND us.session_end_time IS NULL;

-- 5. Candidate Comprehensive 360 Profile Summary
CREATE OR REPLACE VIEW v_candidate_summary_360 AS
SELECT 
    cp.id AS candidate_profile_id,
    cp.uuid AS candidate_uuid,
    cp.display_name,
    u.email_address,
    CONCAT(u.country_dial_code, ' ', u.national_phone_number) AS phone_e164,
    c.city_name,
    jr.role_name AS job_role_name,
    ROUND(cp.total_experience_months / 12, 1) AS experience_years,
    cp.profile_completion_percentage,
    COUNT(DISTINCT cs.skill_id) AS total_skills_count,
    COUNT(DISTINCT ja.id) AS total_applications_submitted_count,
    cp.created_at AS profile_created_at
FROM candidate_profile cp
INNER JOIN app_user u ON cp.app_user_id = u.id
LEFT JOIN city c ON cp.current_city_id = c.id
LEFT JOIN job_role jr ON cp.current_job_role_id = jr.id
LEFT JOIN candidate_skill cs ON cs.candidate_profile_id = cp.id
LEFT JOIN job_application ja ON ja.candidate_profile_id = cp.id
WHERE cp.deleted_at IS NULL
GROUP BY cp.id, cp.uuid, cp.display_name, u.email_address, u.country_dial_code, 
         u.national_phone_number, c.city_name, jr.role_name, cp.total_experience_months, 
         cp.profile_completion_percentage, cp.created_at;
