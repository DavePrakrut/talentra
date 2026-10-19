"""
Synthetic Seed Data Generator for Talentra Database
Populates realistic distributions across all 11 modules:
- Multilingual candidates, mononyms, career gaps, disclosed/undisclosed salaries
- Corporate organizations, office locations, verified tax IDs
- Job requisitions with screening questionnaires and required skills
- Multi-stage applications pipeline (applied -> shortlisted -> interviewed -> offered -> joined)
- Dedicated gig marketplace with availability, assignments, ratings, and external handoffs
- Licences, seat allocations, hardware device bindings, active sessions
- Append-only wallet transactions, payments, invoices, download history
- Notification delivery queues, community discussions, support tickets
- Dimensional analytics star schema and salary benchmarks

Supports CLI flags:
  python scripts/seed_generator.py --candidates 500 --jobs 100 --applications 1500
"""

import sys
import os
import random
import uuid
import hashlib
from datetime import datetime, timedelta

# Force UTF-8 stdout
if sys.platform == 'win32':
    try:
        sys.stdout.reconfigure(encoding='utf-8')
    except Exception:
        pass

sys.path.append(os.path.dirname(os.path.abspath(__file__)))
import db_config

FIRST_NAMES = [
    "Aarav", "Vivaan", "Aditya", "Vihaan", "Arjun", "Sai", "Reyansh", "Ayaan", "Krishna", "Ishaan",
    "Diya", "Saanvi", "Ananya", "Aadhya", "Pari", "Chiara", "Elena", "Sophia", "Liam", "Noah",
    "James", "Alexander", "Wei", "Mei", "Hiroshi", "Yuki", "Fatima", "Omar", "Amina", "Zayd"
]

LAST_NAMES = [
    "Sharma", "Verma", "Patel", "Reddy", "Nair", "Iyer", "Rao", "Gupta", "Singh", "Kumar",
    "Smith", "Johnson", "Williams", "Brown", "Jones", "Miller", "Davis", "Wilson", "Taylor", "Anderson",
    "Müller", "Schmidt", "Tanaka", "Sato", "Chen", "Wang", "Al-Mansoor", "Khan", None # Mononyms support
]

TECH_SKILLS = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15] # From skill table
CITIES = [1, 2, 3, 4, 5, 6, 7, 8, 9] # Bengaluru, Mumbai, Pune, Delhi, Hyderabad, Chennai, SF, NYC, London
ROLES = [1, 2, 3, 4, 5, 6, 7, 8] # Full Stack, Backend, Frontend, DevOps, Data Scientist, DBA, Analyst, PM

def generate_seed_data(num_candidates=250, num_jobs=50, num_applications=600):
    conn = db_config.get_connection()
    cursor = conn.cursor()

    print("================================================================")
    print("Generating Synthetic Seed Dataset for Talentra")
    print(f"Target Scale: {num_candidates} Candidates | {num_jobs} Jobs | {num_applications} Applications")
    print("================================================================")

    # Clean previous dynamic seed data
    print("Resetting previous dynamic data ... ", end='', flush=True)
    tables_to_clear = [
        "fact_application_event", "dim_candidate", "dim_job", "dim_organisation",
        "salary_benchmark", "community_reaction", "community_post", "notification_delivery",
        "candidate_profile_download_history", "wallet_transaction", "wallet_account",
        "session_revocation_event", "user_session", "user_device", "licence_seat_allocation",
        "subscription_period", "subscription_licence", "gig_rating", "gig_earnings_reference",
        "gig_assignment", "gig_application", "gig_request", "gig_availability",
        "gig_worker_profile", "job_interview", "job_application_status_history",
        "job_questionnaire_response", "job_application", "job_question", "job_questionnaire",
        "job_requirement_skill", "job_requirement", "privacy_block_entry", "candidate_resume",
        "candidate_skill", "candidate_work_experience", "candidate_education",
        "candidate_profile", "user_preference", "user_credential", "recruiter_assignment",
        "office_location", "organisation_verification", "account_administrator",
        "user_role_assignment", "app_user", "organisation"
    ]
    cursor.execute("SET FOREIGN_KEY_CHECKS = 0;")
    for tbl in tables_to_clear:
        cursor.execute(f"TRUNCATE TABLE {tbl};")
    cursor.execute("SET FOREIGN_KEY_CHECKS = 1;")
    print("DONE")

    # 1. Create System Admin and Corporate Users
    print("[1/10] Seeding Admin, Employer & Recruiter Accounts ... ", end='', flush=True)
    org_ids = []
    recruiter_user_ids = []
    employer_user_ids = []

    # Create 5 Employer Companies
    companies = [
        ("Acme Technologies Private Limited", "Acme Tech", "ENTERPRISE", 1, "https://acmetech.example.com", "contact@acmetech.example.com"),
        ("Globex FinTech Solutions Ltd", "Globex FinTech", "ENTERPRISE", 2, "https://globex.example.com", "careers@globex.example.com"),
        ("BioHealth Digital Informatics", "BioHealth", "SME", 3, "https://biohealth.example.com", "hr@biohealth.example.com"),
        ("Apex Cloud Sourcing Partners", "Apex Sourcing", "STAFFING_AGENCY", 1, "https://apexsourcing.example.com", "info@apexsourcing.example.com"),
        ("QuickGig Workforce Logistics", "QuickGig", "ENTERPRISE", 4, "https://quickgig.example.com", "support@quickgig.example.com")
    ]

    for legal, trade, org_type, ind_id, site, mail in companies:
        cursor.execute("""
            INSERT INTO organisation (uuid, legal_name, trade_name, organisation_type_code, industry_sector_id, company_website_url, primary_email_address, verification_status_code, account_status_code)
            VALUES (%s, %s, %s, %s, %s, %s, %s, 'VERIFIED', 'ACTIVE')
            ON DUPLICATE KEY UPDATE trade_name = VALUES(trade_name);
        """, (str(uuid.uuid4()), legal, trade, org_type, ind_id, site, mail))
        cursor.execute("SELECT id FROM organisation WHERE legal_name = %s", (legal,))
        org_id = cursor.fetchone()[0]
        org_ids.append(org_id)

        # Seed Office Location for Org
        cursor.execute("""
            INSERT INTO office_location (uuid, organisation_id, location_label, city_id, street_address_line1, postal_code, is_headquarters)
            VALUES (%s, %s, 'HEADQUARTERS', 1, '100 Outer Ring Road, Tech Park', '560103', TRUE);
        """, (str(uuid.uuid4()), org_id))

        # Seed Organisation Tax Verification
        tax_hash = hashlib.sha256(f"GSTIN_{org_id}".encode()).hexdigest()
        cursor.execute("""
            INSERT INTO organisation_verification (uuid, organisation_id, identifier_type_code, identifier_value_masked, identifier_hash, country_id, verification_status_code)
            VALUES (%s, %s, 'GSTIN', '29AAAAA0000A1Z5', %s, 1, 'VERIFIED')
            ON DUPLICATE KEY UPDATE verification_status_code = 'VERIFIED';
        """, (str(uuid.uuid4()), org_id, tax_hash))

        # Seed Corporate Wallet Account
        cursor.execute("""
            INSERT INTO wallet_account (uuid, organisation_id, current_credit_balance, currency_code, wallet_status_code)
            VALUES (%s, %s, 50000.00, 'INR', 'ACTIVE')
            ON DUPLICATE KEY UPDATE current_credit_balance = 50000.00;
        """, (str(uuid.uuid4()), org_id))

        # Seed Corporate Subscription Licence
        licence_key = f"LIC-{org_id}-{str(uuid.uuid4())[:8].upper()}"
        cursor.execute("""
            INSERT INTO subscription_licence (uuid, organisation_id, licence_key, licence_tier_code, max_users, max_devices_per_user, valid_from_date, valid_to_date, is_active)
            VALUES (%s, %s, %s, 'ENTERPRISE_PRO', 10, 3, '2026-01-01', '2027-01-01', TRUE);
        """, (str(uuid.uuid4()), org_id, licence_key))
        cursor.execute("SELECT id FROM subscription_licence WHERE licence_key = %s", (licence_key,))
        lic_id = cursor.fetchone()[0]

        # Seed Non-Overlapping Subscription Period
        cursor.execute("""
            INSERT INTO subscription_period (uuid, subscription_licence_id, subscription_plan_id, period_start_date, period_end_date, period_status_code)
            VALUES (%s, %s, 2, '2026-01-01', '2027-01-01', 'ACTIVE');
        """, (str(uuid.uuid4()), lic_id))

    # Seed Recruiters & Admin Users
    for i, org_id in enumerate(org_ids):
        user_email = f"recruiter_{org_id}@talentra-test.com"
        cursor.execute("""
            INSERT INTO app_user (uuid, email_address, country_dial_code, national_phone_number, user_status_code, is_email_verified, is_phone_verified)
            VALUES (%s, %s, '+91', %s, 'ACTIVE', TRUE, TRUE)
            ON DUPLICATE KEY UPDATE id=LAST_INSERT_ID(id);
        """, (str(uuid.uuid4()), user_email, f"98765432{i:02d}"))
        recruiter_id = cursor.lastrowid
        recruiter_user_ids.append(recruiter_id)

        # Credentials & Role
        cursor.execute("""
            INSERT INTO user_credential (uuid, app_user_id, password_hash, password_salt)
            VALUES (%s, %s, 'hashed_pw_argon2id', 'salt123')
            ON DUPLICATE KEY UPDATE password_changed_at = NOW(6);
        """, (str(uuid.uuid4()), recruiter_id))

        cursor.execute("""
            INSERT INTO user_role_assignment (app_user_id, role_definition_id)
            VALUES (%s, 7) -- 7 is RECRUITER
            ON DUPLICATE KEY UPDATE is_active = TRUE;
        """, (recruiter_id,))

        cursor.execute("""
            INSERT INTO recruiter_assignment (uuid, organisation_id, recruiter_user_id, assignment_role_code, effective_from_date, effective_to_date, is_active)
            VALUES (%s, %s, %s, 'INTERNAL_RECRUITER', '2026-01-01', NULL, TRUE);
        """, (str(uuid.uuid4()), org_id, recruiter_id))

        # Seat Allocation
        cursor.execute("SELECT id FROM subscription_licence WHERE organisation_id = %s LIMIT 1", (org_id,))
        lic_row = cursor.fetchone()
        if lic_row:
            cursor.execute("""
                INSERT INTO licence_seat_allocation (uuid, subscription_licence_id, app_user_id)
                VALUES (%s, %s, %s)
                ON DUPLICATE KEY UPDATE is_active = TRUE;
            """, (str(uuid.uuid4()), lic_row[0], recruiter_id))

    print("DONE")

    # 2. Seed Candidates & Profiles
    print(f"[2/10] Seeding {num_candidates} Candidate Profiles with Education, Experience & Skills ... ", end='', flush=True)
    candidate_profile_ids = []
    candidate_user_ids = []

    for i in range(1, num_candidates + 1):
        fn = random.choice(FIRST_NAMES)
        ln = random.choice(LAST_NAMES)
        display_name = f"{fn} {ln}" if ln else fn
        email = f"candidate_{i}_{fn.lower()}@talentra-sample.org"
        phone = f"912345{i:04d}"

        cursor.execute("""
            INSERT INTO app_user (uuid, email_address, country_dial_code, national_phone_number, user_status_code, is_email_verified)
            VALUES (%s, %s, '+91', %s, 'ACTIVE', TRUE)
            ON DUPLICATE KEY UPDATE id=LAST_INSERT_ID(id);
        """, (str(uuid.uuid4()), email, phone))
        u_id = cursor.lastrowid
        candidate_user_ids.append(u_id)

        # Role = CANDIDATE (5)
        cursor.execute("""
            INSERT INTO user_role_assignment (app_user_id, role_definition_id)
            VALUES (%s, 5)
            ON DUPLICATE KEY UPDATE is_active = TRUE;
        """, (u_id,))

        # Preferences
        cursor.execute("""
            INSERT INTO user_preference (app_user_id, preferred_ui_language_code)
            VALUES (%s, 'en')
            ON DUPLICATE KEY UPDATE is_email_notification_enabled = TRUE;
        """, (u_id,))

        exp_months = random.randint(0, 180) # 0 to 15 years
        salary_status = random.choice(['DISCLOSED', 'DISCLOSED', 'UNDISCLOSED', 'NOT_APPLICABLE'])
        current_sal = round(random.uniform(400000, 3500000), 2) if salary_status == 'DISCLOSED' else None
        expected_sal = round(current_sal * 1.25, 2) if current_sal else (round(random.uniform(500000, 4000000), 2) if salary_status != 'NOT_APPLICABLE' else None)

        role_id = random.choice(ROLES)
        city_id = random.choice(CITIES)
        completion_pct = round(random.uniform(50.0, 100.0), 2)

        cursor.execute("""
            INSERT INTO candidate_profile (
                uuid, app_user_id, first_name, last_name, display_name, current_city_id, 
                current_job_role_id, total_experience_months, current_salary, expected_salary, 
                salary_currency_code, salary_disclosure_status, notice_period_days, profile_completion_percentage, is_actively_looking
            ) VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, 'INR', %s, %s, %s, TRUE);
        """, (
            str(uuid.uuid4()), u_id, fn, ln, display_name, city_id,
            role_id, exp_months, current_sal, expected_sal, salary_status,
            random.choice([0, 15, 30, 60, 90]), completion_pct
        ))
        cand_id = cursor.lastrowid
        candidate_profile_ids.append(cand_id)

        # Candidate Education
        grad_yr = 2024 - (exp_months // 12)
        start_yr = grad_yr - 4
        cursor.execute("""
            INSERT INTO candidate_education (uuid, candidate_profile_id, educational_qualification_id, institution_name, field_of_study, start_year, graduation_year, is_highest_degree)
            VALUES (%s, %s, %s, 'National Institute of Technology', 'Computer Science and Engineering', %s, %s, TRUE);
        """, (str(uuid.uuid4()), cand_id, random.choice([1, 2, 4, 6]), start_yr, grad_yr))

        # Candidate Work Experience (if experienced)
        if exp_months > 6:
            cursor.execute("""
                INSERT INTO candidate_work_experience (uuid, candidate_profile_id, company_name, designation_title, employment_type_lookup_id, start_date, end_date, is_current_job, job_description)
                VALUES (%s, %s, 'Innovative Labs Global', 'Software Systems Developer', 1, '2023-01-01', NULL, TRUE, 'Building scalable microservices');
            """, (str(uuid.uuid4()), cand_id))

        # Candidate Skills (2-5 skills per candidate)
        cand_skills = random.sample(TECH_SKILLS, random.randint(2, 5))
        for s_id in cand_skills:
            cursor.execute("""
                INSERT INTO candidate_skill (candidate_profile_id, skill_id, proficiency_level_code, experience_months, is_verified_by_test)
                VALUES (%s, %s, %s, %s, %s);
            """, (cand_id, s_id, random.choice(['INTERMEDIATE', 'ADVANCED', 'EXPERT']), exp_months, random.choice([True, False])))

        # Candidate Resume
        cursor.execute("""
            INSERT INTO candidate_resume (uuid, candidate_profile_id, resume_title, file_storage_uri, file_size_bytes, resume_raw_text, is_primary_resume)
            VALUES (%s, %s, 'Primary Technical Resume 2026', %s, %s, %s, TRUE);
        """, (str(uuid.uuid4()), cand_id, f"s3://talentra-resumes/{cand_id}.pdf", random.randint(50000, 250000), f"Resume of {display_name}. Skills in software engineering."))

        # Candidate Privacy Blocking (10% of candidates block an employer)
        if i % 10 == 0:
            cursor.execute("""
                INSERT INTO privacy_block_entry (uuid, blocker_candidate_user_id, blocked_entity_type, blocked_target_id, block_reason)
                VALUES (%s, %s, 'ORGANISATION', %s, 'Do not show profile to current company');
            """, (str(uuid.uuid4()), u_id, random.choice(org_ids)))

    print("DONE")

    # 3. Seed Job Requisitions, Questionnaires & Skills
    print(f"[3/10] Seeding {num_jobs} Job Requisitions & Questionnaires ... ", end='', flush=True)
    job_ids = []
    job_titles = [
        "Senior Backend Systems Architect", "Lead Full Stack Developer", "Principal DevOps Engineer",
        "Staff Data Scientist (NLP)", "Frontend UI/UX Specialist", "Cloud Infrastructure Reliability Engineer",
        "Database Administrator & Performance Tuning Lead", "Product Growth Manager"
    ]

    for j in range(1, num_jobs + 1):
        org_id = random.choice(org_ids)
        title = random.choice(job_titles)
        role_id = random.choice(ROLES)
        min_sal = round(random.uniform(800000, 2000000), 2)
        max_sal = round(min_sal * 1.5, 2)

        cursor.execute("""
            INSERT INTO job_requirement (
                uuid, organisation_id, job_role_id, employment_type_lookup_id, work_mode_lookup_id,
                job_title, job_description, positions_count, minimum_experience_months, maximum_experience_months,
                minimum_salary, maximum_salary, publish_state_code, is_open_to_consultants, open_date
            ) VALUES (%s, %s, %s, 1, %s, %s, %s, %s, %s, %s, %s, %s, 'PUBLISHED', %s, '2026-10-01');
        """, (
            str(uuid.uuid4()), org_id, role_id, random.choice([1, 2, 3]),
            title, f"We are seeking an outstanding {title} to build next-generation applications.",
            random.randint(1, 5), random.randint(12, 36), random.randint(48, 120),
            min_sal, max_sal, random.choice([True, False])
        ))
        j_id = cursor.lastrowid
        job_ids.append(j_id)

        # Required skills for job
        req_skills = random.sample(TECH_SKILLS, random.randint(2, 4))
        for s_id in req_skills:
            cursor.execute("""
                INSERT INTO job_requirement_skill (job_requirement_id, skill_id, is_mandatory, minimum_experience_months)
                VALUES (%s, %s, TRUE, 24);
            """, (j_id, s_id))

        # Screening Questionnaire
        cursor.execute("""
            INSERT INTO job_questionnaire (uuid, job_requirement_id, questionnaire_title, passing_score_percentage)
            VALUES (%s, %s, 'Technical Screening & Knockout Questionnaire', 70.00);
        """, (str(uuid.uuid4()), j_id))
        q_id = cursor.lastrowid

        cursor.execute("""
            INSERT INTO job_question (job_questionnaire_id, question_text, question_type_code, is_knockout)
            VALUES (%s, 'Do you have at least 2 years of production experience in SQL optimization?', 'SINGLE_CHOICE', TRUE);
        """, (q_id,))

    print("DONE")

    # 4. Seed Applications & Pipeline
    print(f"[4/10] Seeding {num_applications} Applications Across Hiring Pipeline ... ", end='', flush=True)
    statuses = ['APPLIED', 'SHORTLISTED', 'INTERVIEWED', 'OFFERED', 'JOINED', 'REJECTED']
    status_weights = [0.40, 0.25, 0.15, 0.10, 0.05, 0.05]

    for a in range(1, num_applications + 1):
        j_id = random.choice(job_ids)
        c_id = random.choice(candidate_profile_ids)
        st = random.choices(statuses, weights=status_weights)[0]

        cursor.execute("SELECT id FROM candidate_resume WHERE candidate_profile_id = %s LIMIT 1", (c_id,))
        res_row = cursor.fetchone()
        resume_id = res_row[0] if res_row else 1

        match_pct = round(random.uniform(40.0, 98.0), 2)
        applied_at = datetime.now() - timedelta(days=random.randint(1, 30))

        cursor.execute("""
            INSERT INTO job_application (
                uuid, job_requirement_id, candidate_profile_id, candidate_resume_id,
                application_status_code, match_score_percentage, applied_at
            ) VALUES (%s, %s, %s, %s, %s, %s, %s)
            ON DUPLICATE KEY UPDATE match_score_percentage = VALUES(match_score_percentage);
        """, (str(uuid.uuid4()), j_id, c_id, resume_id, st, match_pct, applied_at))

    print("DONE")

    # 5. Seed Dedicated Gig Marketplace
    print("[5/10] Seeding Gig Worker Profiles, Availability & Gigs ... ", end='', flush=True)
    # Pick 30 candidates to also be gig workers
    gig_worker_ids = []
    for c_user_id in candidate_user_ids[:30]:
        cursor.execute("""
            INSERT INTO gig_worker_profile (
                uuid, app_user_id, headline, service_offerings_summary, hourly_charge_rate, 
                overall_rating_average, completed_gigs_count, is_available_for_instant_dispatch
            ) VALUES (%s, %s, 'Senior Cloud & Database Optimization Specialist', 'Database architecture, performance tuning, and schema migration', %s, %s, %s, TRUE)
            ON DUPLICATE KEY UPDATE hourly_charge_rate = VALUES(hourly_charge_rate);
        """, (
            str(uuid.uuid4()), c_user_id, round(random.uniform(800, 2500), 2),
            round(random.uniform(4.0, 5.0), 2), random.randint(3, 45)
        ))
        cursor.execute("SELECT id FROM gig_worker_profile WHERE app_user_id = %s", (c_user_id,))
        gwp_id = cursor.fetchone()[0]
        gig_worker_ids.append(gwp_id)

        # Seed Availability Window
        cursor.execute("""
            INSERT INTO gig_availability (uuid, gig_worker_profile_id, available_start_time, available_end_time, is_booked)
            VALUES (%s, %s, '2026-10-16 08:00:00', '2026-10-16 20:00:00', FALSE);
        """, (str(uuid.uuid4()), gwp_id))

    # Seed 10 Gig Requests
    for g in range(1, 11):
        org_id = random.choice(org_ids)
        rec_id = recruiter_user_ids[0]
        budget = round(random.uniform(15000, 80000), 2)
        handoff_id = f"FULFIL-REF-{str(uuid.uuid4())[:12].upper()}"

        cursor.execute("""
            INSERT INTO gig_request (
                uuid, organisation_id, requester_user_id, city_id, gig_title, 
                gig_description, pricing_model_code, budget_amount, window_start_time, window_end_time, gig_status_code
            ) VALUES (%s, %s, %s, 1, %s, 'Immediate project demand for query optimization', 'FIXED_PRICE', %s, '2026-10-17 09:00:00', '2026-10-18 18:00:00', 'COMPLETED');
        """, (str(uuid.uuid4()), org_id, rec_id, f"Database Tuning Sprint #{g}", budget))
        gr_id = cursor.lastrowid

        # Seed Gig Application
        worker_id = random.choice(gig_worker_ids)
        cursor.execute("""
            INSERT INTO gig_application (uuid, gig_request_id, gig_worker_profile_id, proposed_bid_rate, application_status_code)
            VALUES (%s, %s, %s, %s, 'ACCEPTED')
            ON DUPLICATE KEY UPDATE application_status_code = 'ACCEPTED';
        """, (str(uuid.uuid4()), gr_id, worker_id, budget))
        cursor.execute("SELECT id FROM gig_application WHERE gig_request_id = %s AND gig_worker_profile_id = %s", (gr_id, worker_id))
        gap_id = cursor.fetchone()[0]

        # Seed Gig Assignment with external handoff
        cursor.execute("""
            INSERT INTO gig_assignment (
                uuid, gig_request_id, gig_application_id, gig_worker_profile_id,
                scheduled_start_time, scheduled_end_time, agreed_payout_amount, 
                assignment_status_code, external_handoff_reference_id
            ) VALUES (%s, %s, %s, %s, '2026-10-17 09:00:00', '2026-10-17 18:00:00', %s, 'FULFILLED', %s);
        """, (str(uuid.uuid4()), gr_id, gap_id, worker_id, budget, handoff_id))
        gas_id = cursor.lastrowid

        # Seed External Earnings Reference
        cursor.execute("""
            INSERT INTO gig_earnings_reference (
                uuid, gig_assignment_id, gig_worker_profile_id, estimated_earnings, reconciled_earnings, reconciliation_status_code
            ) VALUES (%s, %s, %s, %s, %s, 'RECONCILED');
        """, (str(uuid.uuid4()), gas_id, worker_id, budget, budget))

        # Seed Gig Rating
        cursor.execute("""
            INSERT INTO gig_rating (
                uuid, gig_assignment_id, requester_user_id, gig_worker_profile_id, 
                rating_score, quality_score, punctuality_score, feedback_review_text
            ) VALUES (%s, %s, %s, %s, 4.8, 5.0, 4.6, 'Exceptional performance in database optimization.');
        """, (str(uuid.uuid4()), gas_id, rec_id, worker_id))

    print("DONE")

    # 6. Seed Licences, Devices & Sessions
    print("[6/10] Seeding Hardware Devices & Active Concurrency Sessions ... ", end='', flush=True)
    for u_id in candidate_user_ids[:15]:
        fp = hashlib.sha256(f"dev_mac_{u_id}".encode()).hexdigest()
        cursor.execute("""
            INSERT INTO user_device (uuid, app_user_id, device_fingerprint_hash, device_name, device_type_code, operating_system)
            VALUES (%s, %s, %s, 'MacBook Pro M2', 'DESKTOP_MAC', 'macOS 15.0')
            ON DUPLICATE KEY UPDATE last_seen_at = NOW(6);
        """, (str(uuid.uuid4()), u_id, fp))
        cursor.execute("SELECT id FROM user_device WHERE app_user_id = %s AND device_fingerprint_hash = %s", (u_id, fp))
        dev_id = cursor.fetchone()[0]

        cursor.execute("""
            INSERT INTO user_session (uuid, app_user_id, user_device_id, session_token_hash, ip_address, is_active)
            VALUES (%s, %s, %s, %s, '103.21.124.5', TRUE);
        """, (str(uuid.uuid4()), u_id, dev_id, hashlib.sha256(f"token_{u_id}".encode()).hexdigest()))

    print("DONE")

    # 7. Seed Financial Ledgers & Profile Downloads
    print("[7/10] Seeding Wallet Transactions & Profile Download Audits ... ", end='', flush=True)
    for org_id in org_ids:
        cursor.execute("SELECT id FROM wallet_account WHERE organisation_id = %s", (org_id,))
        wa_id = cursor.fetchone()[0]

        # Recharge transaction
        cursor.execute("""
            INSERT INTO wallet_transaction (uuid, wallet_account_id, transaction_type_code, transaction_amount, balance_after_transaction, transaction_description)
            VALUES (%s, %s, 'CREDIT_RECHARGE', 50000.00, 50000.00, 'Initial Enterprise Wallet Recharge via Stripe');
        """, (str(uuid.uuid4()), wa_id))

        # Deduct 5 profile downloads
        for dl in range(5):
            cand_profile_id = candidate_profile_ids[dl]
            cursor.execute("SELECT id FROM candidate_resume WHERE candidate_profile_id = %s LIMIT 1", (cand_profile_id,))
            res_id = cursor.fetchone()[0]

            cursor.execute("""
                INSERT INTO candidate_profile_download_history (
                    downloader_user_id, downloader_organisation_id, candidate_profile_id, candidate_resume_id, credit_deduction_amount, ip_address
                ) VALUES (%s, %s, %s, %s, 1.00, '192.168.1.100');
            """, (recruiter_user_ids[0], org_id, cand_profile_id, res_id))

    print("DONE")

    # 8. Seed Notifications Outbox & Community
    print("[8/10] Seeding Notification Outbox & Community Discussions ... ", end='', flush=True)
    for i in range(10):
        u_id = candidate_user_ids[i]
        cursor.execute("""
            INSERT INTO notification_delivery (
                uuid, recipient_user_id, delivery_channel_code, notification_template_code,
                idempotency_key, notification_title, payload_json, delivery_status_code
            ) VALUES (%s, %s, 'EMAIL', 'INTERVIEW_INVITATION_V1', %s, 'Interview Invitation: Backend Systems Lead', '{\"interview_date\": \"2026-10-20\"}', 'QUEUED');
        """, (str(uuid.uuid4()), u_id, str(uuid.uuid4())))

    # Community discussion post
    cursor.execute("""
        INSERT INTO community_post (uuid, author_user_id, post_category_code, post_title, post_content, upvote_count)
        VALUES (%s, %s, 'SALARY_INSIGHTS', '2026 Tech Salary Trends in Bengaluru & Hyderabad', 'A breakdown of median compensation bands across backend and cloud roles.', 42);
    """, (str(uuid.uuid4()), candidate_user_ids[0]))

    print("DONE")

    # 9. Seed Dimensional Analytics Star Schema (Facts & Dims)
    print("[9/10] Populating Dimensional Analytics Layer & Facts ... ", end='', flush=True)
    # Populate dim_organisation
    cursor.execute("""
        INSERT INTO dim_organisation (organisation_id, legal_name, trade_name, organisation_type_code, industry_name, verification_status_code, account_status_code)
        SELECT o.id, o.legal_name, o.trade_name, o.organisation_type_code, i.industry_name, o.verification_status_code, o.account_status_code
        FROM organisation o
        INNER JOIN industry_sector i ON o.industry_sector_id = i.id
        ON DUPLICATE KEY UPDATE legal_name = VALUES(legal_name);
    """)

    # Populate dim_job
    for j_id in job_ids[:10]:
        cursor.execute("""
            INSERT INTO dim_job (job_requirement_id, organisation_id, job_title, job_role_name, industry_name, employment_type_name, work_mode_name, is_open_to_consultants, publish_state_code, created_date)
            SELECT jr.id, jr.organisation_id, jr.job_title, r.role_name, i.industry_name, e.display_name, w.display_name, jr.is_open_to_consultants, jr.publish_state_code, jr.open_date
            FROM job_requirement jr
            INNER JOIN job_role r ON jr.job_role_id = r.id
            INNER JOIN industry_sector i ON r.industry_sector_id = i.id
            INNER JOIN employment_type_lookup e ON jr.employment_type_lookup_id = e.id
            INNER JOIN work_mode_lookup w ON jr.work_mode_lookup_id = w.id
            WHERE jr.id = %s
            ON DUPLICATE KEY UPDATE job_title = VALUES(job_title);
        """, (j_id,))

    # Populate dim_candidate
    for c_id in candidate_profile_ids[:20]:
        cursor.execute("""
            INSERT INTO dim_candidate (candidate_profile_id, city_name, experience_tier_code, profile_completion_percentage, is_actively_looking, registered_date)
            SELECT cp.id, c.city_name, 'MID_4_7', cp.profile_completion_percentage, cp.is_actively_looking, '2026-10-15'
            FROM candidate_profile cp
            LEFT JOIN city c ON cp.current_city_id = c.id
            WHERE cp.id = %s
            ON DUPLICATE KEY UPDATE profile_completion_percentage = VALUES(profile_completion_percentage);
        """, (c_id,))

    # Populate fact_application_event
    cursor.execute("""
        INSERT INTO fact_application_event (
            dim_time_id, dim_job_id, dim_candidate_id, dim_organisation_id, job_application_id, 
            sourcing_channel_code, match_score_percentage, is_applied, is_shortlisted, event_timestamp
        )
        SELECT 1, dj.id, dc.id, do.id, ja.id, ja.sourcing_channel_code, ja.match_score_percentage, 1, 
               CASE WHEN ja.application_status_code != 'APPLIED' THEN 1 ELSE 0 END, ja.applied_at
        FROM job_application ja
        INNER JOIN dim_job dj ON dj.job_requirement_id = ja.job_requirement_id
        INNER JOIN dim_candidate dc ON dc.candidate_profile_id = ja.candidate_profile_id
        INNER JOIN dim_organisation do ON do.organisation_id = dj.organisation_id
        LIMIT 50;
    """)

    print("DONE")

    # 10. Seed Market Salary Benchmarks (Tier 3 Stretch)
    print("[10/10] Seeding Market Salary Benchmarks & Snapshot Aggregates ... ", end='', flush=True)
    benchmarks = [
        (1, 'JUNIOR_1_3', 600000.00, 900000.00, 1200000.00, 1500000.00),
        (1, 'MID_4_7', 1400000.00, 1900000.00, 2500000.00, 3200000.00),
        (1, 'SENIOR_8_12', 2600000.00, 3500000.00, 4500000.00, 5800000.00),
        (2, 'MID_4_7', 1500000.00, 2000000.00, 2600000.00, 3400000.00),
        (4, 'MID_4_7', 1600000.00, 2200000.00, 2800000.00, 3600000.00),
        (5, 'MID_4_7', 1800000.00, 2400000.00, 3200000.00, 4200000.00)
    ]

    for role_id, tier, p25, p50, p75, p90 in benchmarks:
        cursor.execute("""
            INSERT INTO salary_benchmark (
                uuid, job_role_id, experience_tier_code, city_id, percentile_25_salary, 
                percentile_50_salary, percentile_75_salary, percentile_90_salary, sample_size_count, effective_year, effective_quarter
            ) VALUES (%s, %s, %s, 1, %s, %s, %s, %s, 540, 2026, 4)
            ON DUPLICATE KEY UPDATE percentile_50_salary = VALUES(percentile_50_salary);
        """, (str(uuid.uuid4()), role_id, tier, p25, p50, p75, p90))

    cursor.close()
    conn.close()

    print("================================================================")
    print("Synthetic Seed Generation Completed Successfully!")
    print("================================================================")

if __name__ == '__main__':
    generate_seed_data()
