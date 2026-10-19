"""
Talentra Performance & Fixed Query Benchmark Harness
Executes the 12 core workflow queries, calculates latency percentiles (p50, p95, p99),
and captures MySQL 8.0 EXPLAIN execution plans.
Docket Reference: Milestone 20 (Backlog B65), Milestone 21 (Backlog B70-B74)
"""

import sys
import os
import time
import statistics

# Force UTF-8 stdout
if sys.platform == 'win32':
    try:
        sys.stdout.reconfigure(encoding='utf-8')
    except Exception:
        pass

sys.path.append(os.path.dirname(os.path.abspath(__file__)))
import db_config

BENCHMARK_QUERIES = [
    (
        "Query 1: Candidate Search with Privacy Blocking",
        """
        SELECT cp.id, cp.display_name, c.city_name, jr.role_name, cp.total_experience_months, cp.profile_completion_percentage
        FROM candidate_profile cp
        INNER JOIN app_user u ON cp.app_user_id = u.id
        LEFT JOIN city c ON cp.current_city_id = c.id
        LEFT JOIN job_role jr ON cp.current_job_role_id = jr.id
        WHERE cp.deleted_at IS NULL
          AND cp.is_actively_looking = TRUE
          AND cp.current_job_role_id = 1
          AND cp.total_experience_months >= 24
          AND NOT EXISTS (
              SELECT 1 FROM privacy_block_entry pbe
              WHERE pbe.blocker_candidate_user_id = u.id AND pbe.is_active = TRUE
                AND ((pbe.blocked_entity_type = 'ORGANISATION' AND pbe.blocked_target_id = 1)
                  OR (pbe.blocked_entity_type = 'RECRUITER_USER' AND pbe.blocked_target_id = 10))
          )
        ORDER BY cp.profile_completion_percentage DESC, cp.total_experience_months DESC
        LIMIT 50;
        """
    ),
    (
        "Query 2: Employer Hiring Pipeline Funnel Breakdown",
        """
        SELECT ja.job_requirement_id, jr.job_title, o.trade_name AS company_name, COUNT(ja.id) AS total_applicants,
               SUM(CASE WHEN ja.application_status_code = 'APPLIED' THEN 1 ELSE 0 END) AS count_applied,
               SUM(CASE WHEN ja.application_status_code = 'SHORTLISTED' THEN 1 ELSE 0 END) AS count_shortlisted,
               SUM(CASE WHEN ja.application_status_code = 'INTERVIEWED' THEN 1 ELSE 0 END) AS count_interviewed,
               SUM(CASE WHEN ja.application_status_code = 'OFFERED' THEN 1 ELSE 0 END) AS count_offered,
               SUM(CASE WHEN ja.application_status_code = 'JOINED' THEN 1 ELSE 0 END) AS count_joined,
               ROUND(AVG(ja.match_score_percentage), 2) AS average_match_score
        FROM job_application ja
        INNER JOIN job_requirement jr ON ja.job_requirement_id = jr.id
        INNER JOIN organisation o ON jr.organisation_id = o.id
        WHERE jr.organisation_id = 1
          AND jr.publish_state_code = 'PUBLISHED'
        GROUP BY ja.job_requirement_id, jr.job_title, o.trade_name;
        """
    ),
    (
        "Query 3: Multi-Skill Candidate Matching Algorithm",
        """
        SELECT cp.id, cp.display_name, COUNT(jrs.skill_id) AS matched_skills_count,
               ROUND((COUNT(jrs.skill_id) / 3.0) * 100.0, 2) AS skill_match_percentage,
               SUM(CASE WHEN cs.is_verified_by_test = TRUE THEN 1 ELSE 0 END) AS verified_skills_count
        FROM candidate_profile cp
        INNER JOIN app_user u ON cp.app_user_id = u.id
        INNER JOIN candidate_skill cs ON cs.candidate_profile_id = cp.id
        INNER JOIN job_requirement_skill jrs ON jrs.skill_id = cs.skill_id
        WHERE jrs.job_requirement_id = 1
          AND cp.deleted_at IS NULL
        GROUP BY cp.id, cp.display_name
        HAVING matched_skills_count >= 1
        ORDER BY skill_match_percentage DESC, verified_skills_count DESC
        LIMIT 25;
        """
    ),
    (
        "Query 4: Available Gig Worker Discovery",
        """
        SELECT gwp.id, u.id AS worker_user_id, gwp.headline, gwp.hourly_charge_rate, gwp.overall_rating_average,
               gwp.completed_gigs_count, ga.available_start_time, ga.available_end_time
        FROM gig_worker_profile gwp
        INNER JOIN app_user u ON gwp.app_user_id = u.id
        INNER JOIN candidate_profile cp ON cp.app_user_id = u.id
        INNER JOIN gig_availability ga ON ga.gig_worker_profile_id = gwp.id
        WHERE ga.is_booked = FALSE
          AND ga.available_start_time <= '2026-10-16 09:00:00'
          AND ga.available_end_time >= '2026-10-16 18:00:00'
          AND gwp.hourly_charge_rate <= 2000.00
          AND cp.current_city_id = 1
          AND NOT EXISTS (
              SELECT 1 FROM gig_blacklist_worker gbw
              WHERE gbw.organisation_id = 1 AND gbw.gig_worker_profile_id = gwp.id
          )
        ORDER BY gwp.overall_rating_average DESC, gwp.completed_gigs_count DESC
        LIMIT 20;
        """
    ),
    (
        "Query 5: Active Device & Session Limit Concurrency Check",
        """
        SELECT u.id, u.email_address, COALESCE(sl.max_devices_per_user, 2) AS allowed_max_devices,
               COUNT(us.id) AS current_active_sessions_count
        FROM app_user u
        LEFT JOIN licence_seat_allocation lsa ON lsa.app_user_id = u.id AND lsa.is_active = TRUE
        LEFT JOIN subscription_licence sl ON lsa.subscription_licence_id = sl.id 
             AND sl.is_active = TRUE AND CURRENT_DATE() BETWEEN sl.valid_from_date AND sl.valid_to_date
        LEFT JOIN user_session us ON us.app_user_id = u.id AND us.is_active = TRUE AND us.session_end_time IS NULL
        WHERE u.id = 1
        GROUP BY u.id, u.email_address, sl.max_devices_per_user;
        """
    ),
    (
        "Query 6: Recruiter-Scoped Requisition Discovery",
        """
        SELECT jr.id, jr.job_title, o.legal_name, jr.positions_count, jr.positions_filled_count,
               COUNT(ja.id) AS total_applications_received
        FROM recruiter_assignment ra
        INNER JOIN organisation o ON ra.organisation_id = o.id
        INNER JOIN job_requirement jr ON jr.organisation_id = o.id
        LEFT JOIN job_application ja ON ja.job_requirement_id = jr.id
        WHERE ra.recruiter_user_id = 1
          AND ra.is_active = TRUE
          AND (ra.effective_to_date IS NULL OR ra.effective_to_date >= CURRENT_DATE())
          AND jr.deleted_at IS NULL
        GROUP BY jr.id, jr.job_title, o.legal_name, jr.positions_count, jr.positions_filled_count
        ORDER BY jr.id DESC;
        """
    ),
    (
        "Query 7: Append-Only Wallet Ledger Reconciliation",
        """
        SELECT wa.id, wa.organisation_id, wa.current_credit_balance,
               COALESCE(SUM(wt.transaction_amount), 0.00) AS computed_ledger_balance,
               COUNT(wt.id) AS transactions_count
        FROM wallet_account wa
        LEFT JOIN wallet_transaction wt ON wt.wallet_account_id = wa.id
        WHERE wa.organisation_id = 1
        GROUP BY wa.id, wa.organisation_id, wa.current_credit_balance;
        """
    ),
    (
        "Query 8: Gig External Fulfilment Reconciliation Status",
        """
        SELECT ga.id, ga.external_handoff_reference_id, ga.assignment_status_code,
               ger.estimated_earnings, ger.reconciled_earnings, ger.reconciliation_status_code
        FROM gig_assignment ga
        INNER JOIN gig_earnings_reference ger ON ger.gig_assignment_id = ga.id
        WHERE ga.assignment_status_code = 'FULFILLED'
        ORDER BY ga.id DESC
        LIMIT 50;
        """
    ),
    (
        "Query 9: High-Volume Notification Delivery Outbox Polling",
        """
        SELECT nd.id, nd.recipient_user_id, u.email_address, nd.delivery_channel_code,
               nd.notification_template_code, nd.notification_title
        FROM notification_delivery nd
        INNER JOIN app_user u ON nd.recipient_user_id = u.id
        WHERE nd.delivery_status_code = 'QUEUED'
          AND nd.retry_count < 3
        ORDER BY nd.queued_at ASC
        LIMIT 100;
        """
    ),
    (
        "Query 10: Monthly Hiring Funnel & Conversion Analytics",
        """
        SELECT dt.calendar_year, dt.calendar_month, dj.industry_name, dj.job_role_name,
               SUM(fae.is_applied) AS total_applied,
               SUM(fae.is_shortlisted) AS total_shortlisted
        FROM fact_application_event fae
        INNER JOIN dim_time dt ON fae.dim_time_id = dt.id
        INNER JOIN dim_job dj ON fae.dim_job_id = dj.id
        WHERE dt.calendar_year = 2026
        GROUP BY dt.calendar_year, dt.calendar_month, dj.industry_name, dj.job_role_name
        ORDER BY total_applied DESC;
        """
    ),
    (
        "Query 11: Candidate Profile Download Audit History",
        """
        SELECT cpdh.id, o.trade_name, u.email_address, cp.display_name, cpdh.credit_deduction_amount, cpdh.downloaded_at
        FROM candidate_profile_download_history cpdh
        INNER JOIN organisation o ON cpdh.downloader_organisation_id = o.id
        INNER JOIN app_user u ON cpdh.downloader_user_id = u.id
        INNER JOIN candidate_profile cp ON cpdh.candidate_profile_id = cp.id
        WHERE cpdh.downloader_organisation_id = 1
        ORDER BY cpdh.downloaded_at DESC
        LIMIT 50;
        """
    ),
    (
        "Query 12: Salary Percentile Benchmark Comparison",
        """
        SELECT cp.id, cp.display_name, jr.role_name, cp.expected_salary,
               sb.percentile_25_salary, sb.percentile_50_salary, sb.percentile_75_salary
        FROM candidate_profile cp
        INNER JOIN job_role jr ON cp.current_job_role_id = jr.id
        LEFT JOIN salary_benchmark sb ON sb.job_role_id = cp.current_job_role_id AND sb.effective_year = 2026
        WHERE cp.deleted_at IS NULL AND cp.expected_salary IS NOT NULL
        LIMIT 50;
        """
    )
]

def run_benchmark():
    conn = db_config.get_connection()
    cursor = conn.cursor()

    print("================================================================================")
    print("Talentra Performance Benchmark Harness (12 Fixed Core Queries)")
    print("Methodology: 1 Warmup run + 10 iterations per query; Latencies in milliseconds (ms)")
    print("================================================================================")
    print(f"{'Query Title':<48} | {'Rows':<5} | {'p50':<8} | {'p95':<8} | {'p99':<8}")
    print("-" * 88)

    benchmark_results = []

    for idx, (title, sql) in enumerate(BENCHMARK_QUERIES, 1):
        # 1. Warm-up run
        cursor.execute(sql)
        rows = cursor.fetchall()
        row_count = len(rows)

        # 2. Benchmark iterations
        timings = []
        for _ in range(10):
            t0 = time.perf_counter()
            cursor.execute(sql)
            cursor.fetchall()
            t1 = time.perf_counter()
            timings.append((t1 - t0) * 1000.0)

        p50 = statistics.median(timings)
        p95 = statistics.quantiles(timings, n=20)[18] if len(timings) >= 20 else max(timings)
        p99 = max(timings)

        print(f"{title:<48} | {row_count:<5} | {p50:6.2f}ms | {p95:6.2f}ms | {p99:6.2f}ms")

        # 3. Capture EXPLAIN execution plan
        cursor.execute(f"EXPLAIN {sql}")
        plan_rows = cursor.fetchall()
        plan_columns = [col[0] for col in cursor.description]

        benchmark_results.append({
            'index': idx,
            'title': title,
            'row_count': row_count,
            'p50': round(p50, 2),
            'p95': round(p95, 2),
            'p99': round(p99, 2),
            'sql': sql.strip(),
            'plan_columns': plan_columns,
            'plan_rows': plan_rows
        })

    cursor.close()
    conn.close()

    print("================================================================================")
    print("All 12 queries benchmarked successfully!")
    print("================================================================================")
    return benchmark_results

if __name__ == '__main__':
    run_benchmark()
