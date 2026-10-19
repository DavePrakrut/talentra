"""
Talentra Enterprise Multi-Portal Backend Server
Connects directly to MySQL Server 8.0 (InnoDB) and powers the three interactive portals:
  1. Candidate & Gig Portal (Job Seeker Perspective)
  2. Employer & Recruiter Portal (Company / Recruiter Perspective)
  3. Talentra Admin Console (Platform Governance & Operations)
Zero external web framework dependencies - standard library HTTP server with full REST APIs.
"""

import sys
import os
import json
import time
import uuid
from datetime import datetime, date
from decimal import Decimal
from http.server import ThreadingHTTPServer, SimpleHTTPRequestHandler
import urllib.parse

# Force UTF-8 stdout
if sys.platform == 'win32':
    try:
        sys.stdout.reconfigure(encoding='utf-8')
    except Exception:
        pass

sys.path.append(os.path.dirname(os.path.abspath(__file__)))
import db_config
from run_benchmark import BENCHMARK_QUERIES

WEB_DIR = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), 'web')

def json_serial(obj):
    """JSON serializer for objects not serializable by default json code"""
    if isinstance(obj, (datetime, date)):
        return obj.isoformat()
    elif isinstance(obj, Decimal):
        return float(obj)
    elif isinstance(obj, bytes):
        return obj.decode('utf-8', errors='replace')
    raise TypeError(f"Type {type(obj)} not serializable")

def log_audit_event(cur, actor_user_id, action_type, entity_name, entity_id, ip_address="127.0.0.1", pre_state=None, post_state=None):
    """Utility helper to record an append-only audit event in audit_log"""
    cur.execute("""
        INSERT INTO audit_log (
            uuid, actor_user_id, action_type, target_entity_name, target_entity_id,
            ip_address, pre_change_state, post_change_state, action_timestamp
        ) VALUES (
            UUID(), %s, %s, %s, %s, %s, %s, %s, NOW(6)
        );
    """, (
        actor_user_id, action_type, entity_name, entity_id, ip_address,
        json.dumps(pre_state) if pre_state else None,
        json.dumps(post_state) if post_state else None
    ))

class TalentraRequestHandler(SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=WEB_DIR, **kwargs)

    def do_GET(self):
        parsed_url = urllib.parse.urlparse(self.path)
        path = parsed_url.path
        query_params = urllib.parse.parse_qs(parsed_url.query)

        # Static Assets
        if path == '/' or path == '/index.html':
            self.serve_file(os.path.join(WEB_DIR, 'index.html'), 'text/html; charset=utf-8')
        elif path.startswith('/static/'):
            file_name = path[len('/static/'):]
            file_path = os.path.join(WEB_DIR, 'static', file_name)
            mime_type = 'text/css' if file_name.endswith('.css') else 'application/javascript' if file_name.endswith('.js') else 'application/octet-stream'
            self.serve_file(file_path, mime_type)
        
        # Core Shared & Meta APIs
        elif path == '/api/portals/meta':
            self.handle_api_portals_meta()
        elif path == '/api/kpi':
            self.handle_api_kpi()
        elif path == '/api/candidates':
            self.handle_api_candidates(query_params)
        elif path == '/api/pipeline':
            self.handle_api_pipeline(query_params)
        elif path == '/api/gigs':
            self.handle_api_gigs()
        elif path == '/api/benchmark/queries':
            self.handle_api_benchmark_queries()
        elif path == '/api/schema':
            self.handle_api_schema()
        elif path == '/api/audit':
            self.handle_api_audit()

        # Portal 1: Candidate Specific APIs
        elif path == '/api/candidate/profile':
            self.handle_api_candidate_profile(query_params)
        elif path == '/api/candidate/jobs':
            self.handle_api_candidate_jobs(query_params)
        elif path == '/api/candidate/my_applications':
            self.handle_api_candidate_my_applications(query_params)
        elif path == '/api/candidate/privacy_blocks':
            self.handle_api_candidate_privacy_blocks(query_params)

        # Portal 2: Employer Specific APIs
        elif path == '/api/employer/overview':
            self.handle_api_employer_overview(query_params)
        elif path == '/api/employer/jobs':
            self.handle_api_employer_jobs(query_params)
        elif path == '/api/employer/job_applicants':
            self.handle_api_employer_job_applicants(query_params)
        elif path == '/api/employer/wallet':
            self.handle_api_employer_wallet(query_params)

        # Portal 3: Admin Specific APIs
        elif path == '/api/admin/organisations':
            self.handle_api_admin_organisations()
        elif path == '/api/admin/sessions':
            self.handle_api_admin_sessions()
        else:
            self.send_error(404, "Endpoint not found")

    def do_POST(self):
        parsed_url = urllib.parse.urlparse(self.path)
        path = parsed_url.path

        content_length = int(self.headers.get('Content-Length', 0))
        post_data = self.rfile.read(content_length)
        body = json.loads(post_data.decode('utf-8')) if post_data else {}

        # Benchmarks
        if path == '/api/benchmark/run':
            self.handle_api_benchmark_run(body)

        # Portal 1: Candidate Actions
        elif path == '/api/candidate/apply':
            self.handle_api_candidate_apply(body)
        elif path == '/api/candidate/block_entity':
            self.handle_api_candidate_block_entity(body)
        elif path == '/api/candidate/unblock_entity':
            self.handle_api_candidate_unblock_entity(body)
        elif path == '/api/candidate/gig_bid':
            self.handle_api_candidate_gig_bid(body)

        # Portal 2: Employer Actions
        elif path == '/api/employer/create_job':
            self.handle_api_employer_create_job(body)
        elif path == '/api/employer/advance_stage':
            self.handle_api_employer_advance_stage(body)
        elif path == '/api/employer/download_resume':
            self.handle_api_employer_download_resume(body)
        elif path == '/api/employer/recharge_wallet':
            self.handle_api_employer_recharge_wallet(body)
        elif path == '/api/employer/create_gig':
            self.handle_api_employer_create_gig(body)
        elif path == '/api/employer/accept_gig':
            self.handle_api_employer_accept_gig(body)

        # Portal 3: Admin Actions
        elif path == '/api/admin/verify_organisation':
            self.handle_api_admin_verify_organisation(body)
        elif path == '/api/admin/revoke_session':
            self.handle_api_admin_revoke_session(body)
        elif path == '/api/admin/test_session_limit':
            self.handle_api_admin_test_session_limit(body)
        else:
            self.send_error(404, "Endpoint not found")

    def serve_file(self, file_path, content_type):
        if not os.path.exists(file_path):
            self.send_error(404, "File not found")
            return
        with open(file_path, 'rb') as f:
            content = f.read()
        self.send_response(200)
        self.send_header('Content-Type', content_type)
        self.send_header('Content-Length', str(len(content)))
        self.send_header('Cache-Control', 'no-cache')
        self.end_headers()
        self.wfile.write(content)

    def send_json(self, data, status_code=200):
        json_data = json.dumps(data, default=json_serial).encode('utf-8')
        self.send_response(status_code)
        self.send_header('Content-Type', 'application/json; charset=utf-8')
        self.send_header('Content-Length', str(len(json_data)))
        self.send_header('Access-Control-Allow-Origin', '*')
        self.send_header('Access-Control-Allow-Methods', 'GET, POST, OPTIONS')
        self.send_header('Access-Control-Allow-Headers', 'Content-Type')
        self.end_headers()
        self.wfile.write(json_data)

    # =========================================================================
    # METADATA & KPI APIS
    # =========================================================================
    def handle_api_portals_meta(self):
        try:
            conn = db_config.get_connection()
            cur = conn.cursor(dictionary=True)

            # Available Candidate Personas
            cur.execute("""
                SELECT cp.id, cp.display_name, cp.current_job_role_id, jr.role_name,
                       c.city_name, u.email_address, cp.total_experience_months, cp.app_user_id
                FROM candidate_profile cp
                INNER JOIN app_user u ON cp.app_user_id = u.id
                LEFT JOIN job_role jr ON cp.current_job_role_id = jr.id
                LEFT JOIN city c ON cp.current_city_id = c.id
                WHERE cp.deleted_at IS NULL
                ORDER BY cp.id ASC LIMIT 25;
            """)
            candidates = cur.fetchall()

            # Available Employer Personas
            cur.execute("""
                SELECT o.id, o.legal_name, o.trade_name, o.verification_status_code,
                       c.city_name, wa.current_credit_balance,
                       (SELECT u.id FROM app_user u 
                        INNER JOIN recruiter_assignment ra ON ra.recruiter_user_id = u.id 
                        WHERE ra.organisation_id = o.id AND ra.is_active = TRUE LIMIT 1) AS primary_recruiter_user_id
                FROM organisation o
                LEFT JOIN office_location ol ON ol.organisation_id = o.id AND ol.is_headquarters = TRUE
                LEFT JOIN city c ON ol.city_id = c.id
                LEFT JOIN wallet_account wa ON wa.organisation_id = o.id
                WHERE o.deleted_at IS NULL
                ORDER BY o.id ASC;
            """)
            organisations = cur.fetchall()

            # Job Roles, Cities, Skills, Employment Types, Work Modes
            cur.execute("SELECT id, role_name FROM job_role WHERE is_active = TRUE ORDER BY display_order;")
            roles = cur.fetchall()
            cur.execute("SELECT id, city_name FROM city WHERE is_active = TRUE ORDER BY display_order;")
            cities = cur.fetchall()
            cur.execute("SELECT id, skill_name FROM skill WHERE is_active = TRUE ORDER BY skill_name LIMIT 100;")
            skills = cur.fetchall()
            cur.execute("SELECT id, lookup_code, display_name FROM employment_type_lookup WHERE is_active = TRUE ORDER BY sort_order;")
            employment_types = cur.fetchall()
            cur.execute("SELECT id, lookup_code, display_name FROM work_mode_lookup WHERE is_active = TRUE ORDER BY sort_order;")
            work_modes = cur.fetchall()

            cur.close()
            conn.close()
            self.send_json({
                'success': True,
                'data': {
                    'candidates': candidates,
                    'organisations': organisations,
                    'roles': roles,
                    'cities': cities,
                    'skills': skills,
                    'employment_types': employment_types,
                    'work_modes': work_modes
                }
            })
        except Exception as e:
            self.send_json({'success': False, 'error': str(e)}, 500)

    def handle_api_kpi(self):
        try:
            conn = db_config.get_connection()
            cur = conn.cursor(dictionary=True)

            stats = {}
            cur.execute("SELECT COUNT(*) AS total_candidates FROM candidate_profile WHERE deleted_at IS NULL;")
            stats['total_candidates'] = cur.fetchone()['total_candidates']

            cur.execute("SELECT COUNT(*) AS total_organisations FROM organisation WHERE deleted_at IS NULL;")
            stats['total_organisations'] = cur.fetchone()['total_organisations']

            cur.execute("SELECT COUNT(*) AS total_jobs FROM job_requirement WHERE deleted_at IS NULL;")
            stats['total_jobs'] = cur.fetchone()['total_jobs']

            cur.execute("""
                SELECT 
                    COUNT(*) AS total_applications,
                    SUM(CASE WHEN application_status_code = 'APPLIED' THEN 1 ELSE 0 END) AS applied,
                    SUM(CASE WHEN application_status_code = 'SHORTLISTED' THEN 1 ELSE 0 END) AS shortlisted,
                    SUM(CASE WHEN application_status_code = 'INTERVIEWED' THEN 1 ELSE 0 END) AS interviewed,
                    SUM(CASE WHEN application_status_code = 'OFFERED' THEN 1 ELSE 0 END) AS offered,
                    SUM(CASE WHEN application_status_code = 'JOINED' THEN 1 ELSE 0 END) AS joined,
                    SUM(CASE WHEN application_status_code = 'REJECTED' THEN 1 ELSE 0 END) AS rejected
                FROM job_application WHERE deleted_at IS NULL;
            """)
            stats['pipeline'] = cur.fetchone()

            cur.execute("""
                SELECT 
                    (SELECT COUNT(*) FROM gig_worker_profile) AS total_workers,
                    (SELECT COUNT(*) FROM gig_request) AS total_gig_requests,
                    (SELECT COUNT(*) FROM gig_assignment) AS total_assignments,
                    (SELECT COALESCE(SUM(agreed_payout_amount), 0) FROM gig_assignment WHERE assignment_status_code = 'FULFILLED') AS total_gig_payout
            """)
            stats['gig_stats'] = cur.fetchone()

            cur.execute("""
                SELECT 
                    COALESCE(SUM(current_credit_balance), 0) AS total_wallet_balance,
                    (SELECT COUNT(*) FROM wallet_transaction) AS total_transactions,
                    (SELECT COUNT(*) FROM candidate_profile_download_history) AS total_resume_downloads
                FROM wallet_account;
            """)
            stats['financial'] = cur.fetchone()

            cur.execute("""
                SELECT 
                    (SELECT COUNT(*) FROM user_session WHERE is_active = TRUE AND session_end_time IS NULL) AS active_sessions,
                    (SELECT COUNT(*) FROM user_device) AS registered_devices
            """)
            stats['sessions'] = cur.fetchone()

            cur.close()
            conn.close()
            self.send_json({'success': True, 'data': stats})
        except Exception as e:
            self.send_json({'success': False, 'error': str(e)}, 500)

    # =========================================================================
    # PORTAL 1: CANDIDATE APIS & ACTIONS
    # =========================================================================
    def handle_api_candidate_profile(self, params):
        try:
            candidate_id = params.get('candidate_id', ['1'])[0]
            conn = db_config.get_connection()
            cur = conn.cursor(dictionary=True)

            cur.execute("""
                SELECT 
                    cp.id, cp.uuid, cp.app_user_id, cp.first_name, cp.last_name, cp.display_name,
                    cp.total_experience_months, ROUND(cp.total_experience_months / 12, 1) AS experience_years,
                    cp.current_salary, cp.expected_salary, cp.salary_currency_code, cp.salary_disclosure_status,
                    cp.notice_period_days, cp.profile_completion_percentage, cp.is_actively_looking,
                    u.email_address, CONCAT(u.country_dial_code, ' ', u.national_phone_number) AS phone,
                    c.city_name, jr.role_name
                FROM candidate_profile cp
                INNER JOIN app_user u ON cp.app_user_id = u.id
                LEFT JOIN city c ON cp.current_city_id = c.id
                LEFT JOIN job_role jr ON cp.current_job_role_id = jr.id
                WHERE cp.id = %s;
            """, (int(candidate_id),))
            profile = cur.fetchone()

            if not profile:
                self.send_json({'success': False, 'error': 'Candidate not found'}, 404)
                cur.close()
                conn.close()
                return

            # Skills
            cur.execute("""
                SELECT cs.id, s.skill_name, cs.proficiency_level_code, cs.is_verified_by_test,
                       cs.experience_months
                FROM candidate_skill cs
                INNER JOIN skill s ON cs.skill_id = s.id
                WHERE cs.candidate_profile_id = %s
                ORDER BY cs.is_verified_by_test DESC, s.skill_name ASC;
            """, (int(candidate_id),))
            skills = cur.fetchall()

            # Education
            cur.execute("""
                SELECT ce.institution_name, eq.qualification_name, ce.field_of_study, ce.graduation_year, ce.grade_percentage_or_gpa
                FROM candidate_education ce
                INNER JOIN educational_qualification eq ON ce.educational_qualification_id = eq.id
                WHERE ce.candidate_profile_id = %s
                ORDER BY ce.graduation_year DESC;
            """, (int(candidate_id),))
            education = cur.fetchall()

            # Work Experience
            cur.execute("""
                SELECT company_name, designation_title, start_date, end_date, is_current_job, job_description
                FROM candidate_work_experience
                WHERE candidate_profile_id = %s
                ORDER BY start_date DESC;
            """, (int(candidate_id),))
            experience = cur.fetchall()

            # Resumes
            cur.execute("""
                SELECT id, resume_title, file_mime_type, file_size_bytes, is_primary_resume, created_at
                FROM candidate_resume
                WHERE candidate_profile_id = %s AND deleted_at IS NULL
                ORDER BY is_primary_resume DESC, id DESC;
            """, (int(candidate_id),))
            resumes = cur.fetchall()

            # Active Privacy Blocks
            cur.execute("""
                SELECT pbe.id, pbe.blocked_entity_type, pbe.blocked_target_id, pbe.block_reason, pbe.created_at,
                       CASE 
                           WHEN pbe.blocked_entity_type = 'ORGANISATION' THEN (SELECT trade_name FROM organisation WHERE id = pbe.blocked_target_id)
                           ELSE 'Recruiter ID #' 
                       END AS target_name
                FROM privacy_block_entry pbe
                WHERE pbe.blocker_candidate_user_id = %s AND pbe.is_active = TRUE;
            """, (profile['app_user_id'],))
            privacy_blocks = cur.fetchall()

            cur.close()
            conn.close()
            self.send_json({
                'success': True,
                'data': {
                    'profile': profile,
                    'skills': skills,
                    'education': education,
                    'experience': experience,
                    'resumes': resumes,
                    'privacy_blocks': privacy_blocks
                }
            })
        except Exception as e:
            self.send_json({'success': False, 'error': str(e)}, 500)

    def handle_api_candidate_jobs(self, params):
        """Lists published jobs with matching score and checks if the candidate has applied or blocked the employer"""
        try:
            candidate_id = params.get('candidate_id', ['1'])[0]
            search_query = params.get('q', [None])[0]
            role_id = params.get('role_id', [None])[0]
            city_id = params.get('city_id', [None])[0]

            conn = db_config.get_connection()
            cur = conn.cursor(dictionary=True)

            # Retrieve candidate's user ID and skill IDs
            cur.execute("SELECT app_user_id, current_job_role_id FROM candidate_profile WHERE id = %s;", (int(candidate_id),))
            cand_row = cur.fetchone()
            if not cand_row:
                self.send_json({'success': False, 'error': 'Candidate not found'}, 404)
                cur.close()
                conn.close()
                return

            user_id = cand_row['app_user_id']

            cur.execute("SELECT skill_id FROM candidate_skill WHERE candidate_profile_id = %s;", (int(candidate_id),))
            cand_skill_ids = set(r['skill_id'] for r in cur.fetchall())

            # Query published jobs, ensuring candidate hasn't blocked the posting organization
            query = """
                SELECT 
                    jr.id, jr.uuid, jr.job_title, jr.job_description, jr.positions_count, jr.positions_filled_count,
                    jr.minimum_salary, jr.maximum_salary, jr.salary_currency_code, jr.open_date,
                    jr.minimum_experience_months, jr.is_open_to_consultants,
                    o.id AS organisation_id, o.trade_name AS company_name, o.verification_status_code,
                    c.city_name, jr_role.role_name, etl.display_name AS employment_type, wml.display_name AS work_mode,
                    -- Check if candidate already applied
                    (SELECT ja.application_status_code FROM job_application ja 
                     WHERE ja.job_requirement_id = jr.id AND ja.candidate_profile_id = %s LIMIT 1) AS existing_application_status,
                    -- Required skills summary
                    (SELECT GROUP_CONCAT(s.skill_name SEPARATOR ', ')
                     FROM job_requirement_skill jrs INNER JOIN skill s ON jrs.skill_id = s.id
                     WHERE jrs.job_requirement_id = jr.id LIMIT 4) AS required_skills_list
                FROM job_requirement jr
                INNER JOIN organisation o ON jr.organisation_id = o.id
                LEFT JOIN office_location ol ON jr.office_location_id = ol.id
                LEFT JOIN city c ON ol.city_id = c.id
                LEFT JOIN job_role jr_role ON jr.job_role_id = jr_role.id
                LEFT JOIN employment_type_lookup etl ON jr.employment_type_lookup_id = etl.id
                LEFT JOIN work_mode_lookup wml ON jr.work_mode_lookup_id = wml.id
                WHERE jr.deleted_at IS NULL AND jr.publish_state_code = 'PUBLISHED'
                  -- Exclude if candidate blocked this organisation
                  AND NOT EXISTS (
                      SELECT 1 FROM privacy_block_entry pbe
                      WHERE pbe.blocker_candidate_user_id = %s
                        AND pbe.is_active = TRUE
                        AND pbe.blocked_entity_type = 'ORGANISATION'
                        AND pbe.blocked_target_id = o.id
                  )
            """
            args = [int(candidate_id), user_id]

            if search_query:
                query += " AND (jr.job_title LIKE %s OR o.trade_name LIKE %s)"
                term = f"%{search_query}%"
                args.extend([term, term])

            if role_id and role_id.isdigit():
                query += " AND jr.job_role_id = %s"
                args.append(int(role_id))

            if city_id and city_id.isdigit():
                query += " AND ol.city_id = %s"
                args.append(int(city_id))

            query += " ORDER BY jr.id DESC LIMIT 40;"
            cur.execute(query, tuple(args))
            jobs = cur.fetchall()

            # Calculate match score percentage
            for job in jobs:
                cur.execute("SELECT skill_id, is_mandatory FROM job_requirement_skill WHERE job_requirement_id = %s;", (job['id'],))
                req_skills = cur.fetchall()
                if req_skills:
                    matches = sum(1 for rs in req_skills if rs['skill_id'] in cand_skill_ids)
                    job['match_score'] = round((matches / len(req_skills)) * 100, 1)
                else:
                    job['match_score'] = 75.0 # Baseline

            cur.close()
            conn.close()
            self.send_json({'success': True, 'data': {'jobs': jobs, 'total_count': len(jobs)}})
        except Exception as e:
            self.send_json({'success': False, 'error': str(e)}, 500)

    def handle_api_candidate_apply(self, body):
        """Processes candidate application, inserts into job_application, creates status history and audit record"""
        try:
            candidate_id = body.get('candidate_id')
            job_id = body.get('job_id')

            if not candidate_id or not job_id:
                self.send_json({'success': False, 'error': 'candidate_id and job_id are required'}, 400)
                return

            conn = db_config.get_connection()
            cur = conn.cursor(dictionary=True)

            # Check if candidate exists and retrieve app_user_id
            cur.execute("SELECT app_user_id FROM candidate_profile WHERE id = %s;", (int(candidate_id),))
            cand = cur.fetchone()
            if not cand:
                self.send_json({'success': False, 'error': 'Candidate profile not found'}, 404)
                cur.close()
                conn.close()
                return

            user_id = cand['app_user_id']

            # Check if candidate already applied
            cur.execute("SELECT id FROM job_application WHERE job_requirement_id = %s AND candidate_profile_id = %s;", (int(job_id), int(candidate_id)))
            if cur.fetchone():
                self.send_json({'success': False, 'error': 'You have already applied to this job requisition.'}, 409)
                cur.close()
                conn.close()
                return

            # Check privacy block
            cur.execute("""
                SELECT 1 FROM privacy_block_entry pbe
                INNER JOIN job_requirement jr ON jr.id = %s
                WHERE pbe.blocker_candidate_user_id = %s AND pbe.is_active = TRUE
                  AND pbe.blocked_entity_type = 'ORGANISATION' AND pbe.blocked_target_id = jr.organisation_id;
            """, (int(job_id), user_id))
            if cur.fetchone():
                self.send_json({'success': False, 'error': 'Application blocked: You have an active privacy block against this employer.'}, 403)
                cur.close()
                conn.close()
                return

            # Resolve resume
            cur.execute("SELECT id FROM candidate_resume WHERE candidate_profile_id = %s AND is_primary_resume = TRUE LIMIT 1;", (int(candidate_id),))
            resume_row = cur.fetchone()
            if not resume_row:
                # Get any resume
                cur.execute("SELECT id FROM candidate_resume WHERE candidate_profile_id = %s LIMIT 1;", (int(candidate_id),))
                resume_row = cur.fetchone()

            if not resume_row:
                # Create a default resume version
                cur.execute("""
                    INSERT INTO candidate_resume (
                        uuid, candidate_profile_id, resume_title, file_storage_uri, file_mime_type, file_size_bytes,
                        is_primary_resume, resume_raw_text, created_at
                    ) VALUES (
                        UUID(), %s, 'Primary Resume (Standard)', 's3://talentra-resumes/cand_default.pdf', 'application/pdf', 142800,
                        TRUE, 'Software Engineer resume with full stack development experience.', NOW(6)
                    );
                """, (int(candidate_id),))
                resume_id = cur.lastrowid
            else:
                resume_id = resume_row['id']

            # Calculate match score
            cur.execute("SELECT skill_id FROM candidate_skill WHERE candidate_profile_id = %s;", (int(candidate_id),))
            cand_skill_ids = set(r['skill_id'] for r in cur.fetchall())
            cur.execute("SELECT skill_id FROM job_requirement_skill WHERE job_requirement_id = %s;", (int(job_id),))
            job_skill_ids = set(r['skill_id'] for r in cur.fetchall())

            if job_skill_ids:
                matches = len(cand_skill_ids.intersection(job_skill_ids))
                match_score = round(max(55.0, (matches / len(job_skill_ids)) * 100), 1)
            else:
                match_score = 80.0

            # Insert into job_application
            cur.execute("""
                INSERT INTO job_application (
                    uuid, job_requirement_id, candidate_profile_id, candidate_resume_id,
                    application_status_code, match_score_percentage, sourcing_channel_code,
                    applied_at, created_at, created_by
                ) VALUES (
                    UUID(), %s, %s, %s, 'APPLIED', %s, 'DIRECT_APPLY', NOW(6), NOW(6), %s
                );
            """, (int(job_id), int(candidate_id), resume_id, match_score, user_id))
            app_id = cur.lastrowid

            # Insert into append-only job_application_status_history
            cur.execute("""
                INSERT INTO job_application_status_history (
                    job_application_id, previous_status_code, new_status_code,
                    changed_by_user_id, change_reason_notes, changed_at
                ) VALUES (
                    %s, NULL, 'APPLIED', %s, 'Candidate submitted online application directly', NOW(6)
                );
            """, (app_id, user_id))

            # Record audit log
            log_audit_event(cur, user_id, 'JOB_APPLICATION_SUBMITTED', 'job_application', app_id,
                            post_state={'job_id': int(job_id), 'candidate_id': int(candidate_id), 'match_score': match_score})

            conn.commit()
            cur.close()
            conn.close()

            self.send_json({
                'success': True,
                'message': 'Application submitted successfully!',
                'data': {
                    'application_id': app_id,
                    'match_score': match_score,
                    'status': 'APPLIED'
                }
            })
        except Exception as e:
            self.send_json({'success': False, 'error': str(e)}, 500)

    def handle_api_candidate_my_applications(self, params):
        try:
            candidate_id = params.get('candidate_id', ['1'])[0]
            conn = db_config.get_connection()
            cur = conn.cursor(dictionary=True)

            cur.execute("""
                SELECT 
                    ja.id AS application_id, ja.uuid, ja.application_status_code, ja.match_score_percentage,
                    ja.applied_at, ja.shortlisted_at, ja.interviewed_at, ja.offered_at, ja.joined_at, ja.rejected_at,
                    jr.id AS job_id, jr.job_title, jr.minimum_salary, jr.maximum_salary, jr.salary_currency_code,
                    o.trade_name AS company_name, o.id AS organisation_id, c.city_name,
                    (SELECT change_reason_notes FROM job_application_status_history 
                     WHERE job_application_id = ja.id ORDER BY id DESC LIMIT 1) AS latest_status_note
                FROM job_application ja
                INNER JOIN job_requirement jr ON ja.job_requirement_id = jr.id
                INNER JOIN organisation o ON jr.organisation_id = o.id
                LEFT JOIN office_location ol ON jr.office_location_id = ol.id
                LEFT JOIN city c ON ol.city_id = c.id
                WHERE ja.candidate_profile_id = %s AND ja.deleted_at IS NULL
                ORDER BY ja.applied_at DESC;
            """, (int(candidate_id),))
            applications = cur.fetchall()

            cur.close()
            conn.close()
            self.send_json({'success': True, 'data': {'applications': applications, 'total_count': len(applications)}})
        except Exception as e:
            self.send_json({'success': False, 'error': str(e)}, 500)

    def handle_api_candidate_privacy_blocks(self, params):
        try:
            candidate_id = params.get('candidate_id', ['1'])[0]
            conn = db_config.get_connection()
            cur = conn.cursor(dictionary=True)

            cur.execute("SELECT app_user_id FROM candidate_profile WHERE id = %s;", (int(candidate_id),))
            cand = cur.fetchone()
            if not cand:
                self.send_json({'success': False, 'error': 'Candidate not found'}, 404)
                cur.close()
                conn.close()
                return

            cur.execute("""
                SELECT 
                    pbe.id, pbe.blocked_entity_type, pbe.blocked_target_id, pbe.block_reason,
                    pbe.is_active, pbe.created_at, o.trade_name AS organisation_name
                FROM privacy_block_entry pbe
                LEFT JOIN organisation o ON pbe.blocked_entity_type = 'ORGANISATION' AND pbe.blocked_target_id = o.id
                WHERE pbe.blocker_candidate_user_id = %s
                ORDER BY pbe.is_active DESC, pbe.id DESC;
            """, (cand['app_user_id'],))
            blocks = cur.fetchall()

            cur.close()
            conn.close()
            self.send_json({'success': True, 'data': {'blocks': blocks}})
        except Exception as e:
            self.send_json({'success': False, 'error': str(e)}, 500)

    def handle_api_candidate_block_entity(self, body):
        try:
            candidate_id = body.get('candidate_id')
            target_org_id = body.get('organisation_id')
            reason = body.get('reason', 'Candidate-initiated privacy protection')

            if not candidate_id or not target_org_id:
                self.send_json({'success': False, 'error': 'candidate_id and organisation_id are required'}, 400)
                return

            conn = db_config.get_connection()
            cur = conn.cursor(dictionary=True)

            cur.execute("SELECT app_user_id FROM candidate_profile WHERE id = %s;", (int(candidate_id),))
            cand = cur.fetchone()
            if not cand:
                self.send_json({'success': False, 'error': 'Candidate not found'}, 404)
                cur.close()
                conn.close()
                return

            user_id = cand['app_user_id']

            # Check if block record already exists (upsert)
            cur.execute("""
                SELECT id, is_active FROM privacy_block_entry 
                WHERE blocker_candidate_user_id = %s AND blocked_entity_type = 'ORGANISATION' AND blocked_target_id = %s;
            """, (user_id, int(target_org_id)))
            existing = cur.fetchone()

            if existing:
                cur.execute("""
                    UPDATE privacy_block_entry 
                    SET is_active = TRUE, block_reason = %s, updated_at = NOW(6)
                    WHERE id = %s;
                """, (reason, existing['id']))
                block_id = existing['id']
            else:
                cur.execute("""
                    INSERT INTO privacy_block_entry (
                        uuid, blocker_candidate_user_id, blocked_entity_type, blocked_target_id,
                        block_reason, is_active, created_at
                    ) VALUES (
                        UUID(), %s, 'ORGANISATION', %s, %s, TRUE, NOW(6)
                    );
                """, (user_id, int(target_org_id), reason))
                block_id = cur.lastrowid

            log_audit_event(cur, user_id, 'PRIVACY_BLOCK_ENFORCED', 'privacy_block_entry', block_id,
                            post_state={'target_org_id': int(target_org_id), 'reason': reason})

            conn.commit()
            cur.close()
            conn.close()
            self.send_json({'success': True, 'message': 'Employer blocked successfully! They will not see you in candidate search.'})
        except Exception as e:
            self.send_json({'success': False, 'error': str(e)}, 500)

    def handle_api_candidate_unblock_entity(self, body):
        try:
            candidate_id = body.get('candidate_id')
            target_org_id = body.get('organisation_id')

            conn = db_config.get_connection()
            cur = conn.cursor(dictionary=True)

            cur.execute("SELECT app_user_id FROM candidate_profile WHERE id = %s;", (int(candidate_id),))
            cand = cur.fetchone()
            if not cand:
                self.send_json({'success': False, 'error': 'Candidate not found'}, 404)
                cur.close()
                conn.close()
                return

            user_id = cand['app_user_id']

            cur.execute("""
                UPDATE privacy_block_entry 
                SET is_active = FALSE, updated_at = NOW(6)
                WHERE blocker_candidate_user_id = %s AND blocked_entity_type = 'ORGANISATION' AND blocked_target_id = %s;
            """, (user_id, int(target_org_id)))

            log_audit_event(cur, user_id, 'PRIVACY_BLOCK_REMOVED', 'privacy_block_entry', int(target_org_id),
                            post_state={'target_org_id': int(target_org_id), 'status': 'UNBLOCKED'})

            conn.commit()
            cur.close()
            conn.close()
            self.send_json({'success': True, 'message': 'Employer unblocked successfully.'})
        except Exception as e:
            self.send_json({'success': False, 'error': str(e)}, 500)

    def handle_api_candidate_gig_bid(self, body):
        try:
            candidate_id = body.get('candidate_id')
            gig_request_id = body.get('gig_request_id')
            bid_amount = body.get('bid_amount', 25000)
            pitch_notes = body.get('pitch_notes', 'Available immediately for sprint execution.')

            conn = db_config.get_connection()
            cur = conn.cursor(dictionary=True)

            cur.execute("SELECT app_user_id FROM candidate_profile WHERE id = %s;", (int(candidate_id),))
            cand = cur.fetchone()
            user_id = cand['app_user_id']

            # Resolve gig worker profile
            cur.execute("SELECT id FROM gig_worker_profile WHERE app_user_id = %s;", (user_id,))
            gwp = cur.fetchone()
            if not gwp:
                cur.execute("""
                    INSERT INTO gig_worker_profile (
                        uuid, app_user_id, headline, hourly_charge_rate, is_available_for_instant_dispatch, created_at
                    ) VALUES (
                        UUID(), %s, 'Independent Technical Consultant', 2500.00, TRUE, NOW(6)
                    );
                """, (user_id,))
                worker_id = cur.lastrowid
            else:
                worker_id = gwp['id']

            # Insert gig application
            cur.execute("""
                INSERT INTO gig_application (
                    uuid, gig_request_id, gig_worker_profile_id, application_status_code,
                    proposed_payout_amount, cover_note, applied_at
                ) VALUES (
                    UUID(), %s, %s, 'SUBMITTED', %s, %s, NOW(6)
                );
            """, (int(gig_request_id), worker_id, float(bid_amount), pitch_notes))
            bid_id = cur.lastrowid

            log_audit_event(cur, user_id, 'GIG_BID_SUBMITTED', 'gig_application', bid_id,
                            post_state={'gig_id': int(gig_request_id), 'bid_amount': float(bid_amount)})

            conn.commit()
            cur.close()
            conn.close()
            self.send_json({'success': True, 'message': 'Gig proposal submitted successfully!'})
        except Exception as e:
            self.send_json({'success': False, 'error': str(e)}, 500)

    # =========================================================================
    # PORTAL 2: EMPLOYER & RECRUITER APIS & ACTIONS
    # =========================================================================
    def handle_api_employer_overview(self, params):
        try:
            org_id = params.get('org_id', ['1'])[0]
            conn = db_config.get_connection()
            cur = conn.cursor(dictionary=True)

            cur.execute("""
                SELECT o.id, o.legal_name, o.trade_name, o.verification_status_code,
                       c.city_name, wa.current_credit_balance,
                       (SELECT COUNT(*) FROM job_requirement WHERE organisation_id = o.id AND deleted_at IS NULL) AS total_jobs,
                       (SELECT COUNT(*) FROM job_application ja 
                        INNER JOIN job_requirement jr ON ja.job_requirement_id = jr.id 
                        WHERE jr.organisation_id = o.id AND ja.deleted_at IS NULL) AS total_applicants,
                       (SELECT COUNT(*) FROM recruiter_assignment WHERE organisation_id = o.id AND is_active = TRUE) AS mapped_recruiters
                FROM organisation o
                LEFT JOIN office_location ol ON ol.organisation_id = o.id AND ol.is_headquarters = TRUE
                LEFT JOIN city c ON ol.city_id = c.id
                LEFT JOIN wallet_account wa ON wa.organisation_id = o.id
                WHERE o.id = %s;
            """, (int(org_id),))
            org_data = cur.fetchone()

            if not org_data:
                self.send_json({'success': False, 'error': 'Organisation not found'}, 404)
                cur.close()
                conn.close()
                return

            # Active licence info
            cur.execute("""
                SELECT sl.id, sl.licence_tier_code, sl.max_users, sl.max_devices_per_user,
                       sl.valid_from_date, sl.valid_to_date, sl.is_active
                FROM subscription_licence sl
                WHERE sl.organisation_id = %s AND sl.is_active = TRUE
                ORDER BY sl.id DESC LIMIT 1;
            """, (int(org_id),))
            licence = cur.fetchone()

            cur.close()
            conn.close()
            self.send_json({
                'success': True,
                'data': {
                    'organisation': org_data,
                    'licence': licence
                }
            })
        except Exception as e:
            self.send_json({'success': False, 'error': str(e)}, 500)

    def handle_api_employer_jobs(self, params):
        try:
            org_id = params.get('org_id', ['1'])[0]
            conn = db_config.get_connection()
            cur = conn.cursor(dictionary=True)

            cur.execute("""
                SELECT 
                    jr.id, jr.uuid, jr.job_title, jr.positions_count, jr.positions_filled_count,
                    jr.publish_state_code, jr.minimum_salary, jr.maximum_salary, jr.salary_currency_code,
                    jr.open_date, jr.is_open_to_consultants,
                    c.city_name, jr_role.role_name,
                    COUNT(ja.id) AS total_applicants,
                    SUM(CASE WHEN ja.application_status_code = 'APPLIED' THEN 1 ELSE 0 END) AS stage_applied,
                    SUM(CASE WHEN ja.application_status_code = 'SHORTLISTED' THEN 1 ELSE 0 END) AS stage_shortlisted,
                    SUM(CASE WHEN ja.application_status_code = 'INTERVIEWED' THEN 1 ELSE 0 END) AS stage_interviewed,
                    SUM(CASE WHEN ja.application_status_code = 'OFFERED' THEN 1 ELSE 0 END) AS stage_offered,
                    SUM(CASE WHEN ja.application_status_code = 'JOINED' THEN 1 ELSE 0 END) AS stage_joined,
                    SUM(CASE WHEN ja.application_status_code = 'REJECTED' THEN 1 ELSE 0 END) AS stage_rejected
                FROM job_requirement jr
                LEFT JOIN office_location ol ON jr.office_location_id = ol.id
                LEFT JOIN city c ON ol.city_id = c.id
                LEFT JOIN job_role jr_role ON jr.job_role_id = jr_role.id
                LEFT JOIN job_application ja ON ja.job_requirement_id = jr.id AND ja.deleted_at IS NULL
                WHERE jr.organisation_id = %s AND jr.deleted_at IS NULL
                GROUP BY jr.id, jr.uuid, jr.job_title, jr.positions_count, jr.positions_filled_count,
                         jr.publish_state_code, jr.minimum_salary, jr.maximum_salary, jr.salary_currency_code,
                         jr.open_date, jr.is_open_to_consultants, c.city_name, jr_role.role_name
                ORDER BY jr.id DESC;
            """, (int(org_id),))
            jobs = cur.fetchall()

            cur.close()
            conn.close()
            self.send_json({'success': True, 'data': {'jobs': jobs}})
        except Exception as e:
            self.send_json({'success': False, 'error': str(e)}, 500)

    def handle_api_employer_job_applicants(self, params):
        try:
            job_id_param = params.get('job_id')
            if not job_id_param:
                self.send_json({'success': False, 'error': 'job_id required'}, 400)
                return
            job_id = job_id_param[0] if isinstance(job_id_param, list) else job_id_param

            conn = db_config.get_connection()
            cur = conn.cursor(dictionary=True)

            cur.execute("""
                SELECT 
                    ja.id AS application_id, ja.candidate_profile_id, cp.display_name, cp.first_name, cp.last_name,
                    cp.total_experience_months, ROUND(cp.total_experience_months / 12, 1) AS experience_years,
                    c.city_name, ja.application_status_code, ja.match_score_percentage, ja.applied_at,
                    ja.shortlisted_at, ja.interviewed_at, ja.offered_at, ja.joined_at, ja.rejected_at,
                    u.email_address, CONCAT(u.country_dial_code, ' ', u.national_phone_number) AS phone,
                    (SELECT GROUP_CONCAT(s.skill_name SEPARATOR ', ') 
                     FROM candidate_skill cs INNER JOIN skill s ON cs.skill_id = s.id 
                     WHERE cs.candidate_profile_id = cp.id LIMIT 4) AS candidate_skills
                FROM job_application ja
                INNER JOIN candidate_profile cp ON ja.candidate_profile_id = cp.id
                INNER JOIN app_user u ON cp.app_user_id = u.id
                LEFT JOIN city c ON cp.current_city_id = c.id
                WHERE ja.job_requirement_id = %s AND ja.deleted_at IS NULL
                ORDER BY ja.match_score_percentage DESC, ja.applied_at DESC;
            """, (int(job_id),))
            applicants = cur.fetchall()

            cur.close()
            conn.close()
            self.send_json({'success': True, 'data': {'applicants': applicants, 'total_count': len(applicants)}})
        except Exception as e:
            self.send_json({'success': False, 'error': str(e)}, 500)

    def handle_api_employer_create_job(self, body):
        try:
            org_id = body.get('organisation_id')
            job_title = body.get('job_title')
            job_role_id = body.get('job_role_id', 1)
            city_id = body.get('city_id', 1)
            emp_type_id = body.get('employment_type_id', 1)
            work_mode_id = body.get('work_mode_id', 1)
            positions = body.get('positions_count', 1)
            min_sal = body.get('minimum_salary', 1500000)
            max_sal = body.get('maximum_salary', 2500000)
            description = body.get('description', 'Seeking an experienced professional for high-impact technical initiatives.')
            skill_ids = body.get('skill_ids', [1, 2])
            is_consultant_open = bool(body.get('is_open_to_consultants', False))
            actor_user_id = body.get('actor_user_id', 1)

            if not org_id or not job_title:
                self.send_json({'success': False, 'error': 'organisation_id and job_title are required'}, 400)
                return

            conn = db_config.get_connection()
            cur = conn.cursor(dictionary=True)

            # Resolve an office location for organisation
            cur.execute("SELECT id FROM office_location WHERE organisation_id = %s LIMIT 1;", (int(org_id),))
            loc = cur.fetchone()
            office_loc_id = loc['id'] if loc else None

            # Insert job_requirement
            cur.execute("""
                INSERT INTO job_requirement (
                    uuid, organisation_id, office_location_id, job_role_id,
                    employment_type_lookup_id, work_mode_lookup_id, job_title, job_description,
                    positions_count, positions_filled_count, minimum_experience_months,
                    minimum_salary, maximum_salary, salary_currency_code, publish_state_code,
                    is_open_to_consultants, open_date, created_at, created_by
                ) VALUES (
                    UUID(), %s, %s, %s, %s, %s, %s, %s, %s, 0, 24,
                    %s, %s, 'INR', 'PUBLISHED', %s, CURRENT_DATE(), NOW(6), %s
                );
            """, (int(org_id), office_loc_id, int(job_role_id), int(emp_type_id), int(work_mode_id),
                  job_title, description, int(positions), float(min_sal), float(max_sal),
                  is_consultant_open, actor_user_id))
            job_id = cur.lastrowid

            # Attach required skills
            for sid in skill_ids[:5]:
                cur.execute("""
                    INSERT INTO job_requirement_skill (job_requirement_id, skill_id, is_mandatory, created_at)
                    VALUES (%s, %s, TRUE, NOW(6));
                """, (job_id, int(sid)))

            log_audit_event(cur, actor_user_id, 'JOB_REQUISITION_PUBLISHED', 'job_requirement', job_id,
                            post_state={'job_title': job_title, 'positions': positions})

            conn.commit()
            cur.close()
            conn.close()

            self.send_json({
                'success': True,
                'message': 'Job requisition published successfully!',
                'data': {'job_id': job_id, 'job_title': job_title}
            })
        except Exception as e:
            self.send_json({'success': False, 'error': str(e)}, 500)

    def handle_api_employer_advance_stage(self, body):
        """Advances an applicant stage and logs status history"""
        try:
            app_id = body.get('application_id')
            new_stage = body.get('new_stage')
            notes = body.get('notes', 'Stage updated via Employer ATS dashboard')
            actor_user_id = body.get('actor_user_id', 1)

            valid_stages = ['APPLIED', 'SHORTLISTED', 'INTERVIEWED', 'OFFERED', 'JOINED', 'REJECTED']
            if new_stage not in valid_stages:
                self.send_json({'success': False, 'error': f'Invalid stage. Must be one of {valid_stages}'}, 400)
                return

            conn = db_config.get_connection()
            cur = conn.cursor(dictionary=True)

            cur.execute("SELECT id, job_requirement_id, application_status_code FROM job_application WHERE id = %s;", (int(app_id),))
            app_row = cur.fetchone()
            if not app_row:
                self.send_json({'success': False, 'error': 'Application not found'}, 404)
                cur.close()
                conn.close()
                return

            prev_stage = app_row['application_status_code']

            # Update job_application with appropriate timestamp column
            timestamp_col = {
                'SHORTLISTED': 'shortlisted_at',
                'INTERVIEWED': 'interviewed_at',
                'OFFERED': 'offered_at',
                'JOINED': 'joined_at',
                'REJECTED': 'rejected_at'
            }.get(new_stage)

            if timestamp_col:
                cur.execute(f"""
                    UPDATE job_application 
                    SET application_status_code = %s, {timestamp_col} = NOW(6), updated_at = NOW(6), updated_by = %s
                    WHERE id = %s;
                """, (new_stage, actor_user_id, int(app_id)))
            else:
                cur.execute("""
                    UPDATE job_application 
                    SET application_status_code = %s, updated_at = NOW(6), updated_by = %s
                    WHERE id = %s;
                """, (new_stage, actor_user_id, int(app_id)))

            # If stage is JOINED, increment positions_filled_count on job_requirement
            if new_stage == 'JOINED':
                cur.execute("""
                    UPDATE job_requirement 
                    SET positions_filled_count = LEAST(positions_count, positions_filled_count + 1)
                    WHERE id = %s;
                """, (app_row['job_requirement_id'],))

            # Record in append-only status history
            cur.execute("""
                INSERT INTO job_application_status_history (
                    job_application_id, previous_status_code, new_status_code,
                    changed_by_user_id, change_reason_notes, changed_at
                ) VALUES (
                    %s, %s, %s, %s, %s, NOW(6)
                );
            """, (int(app_id), prev_stage, new_stage, actor_user_id, notes))

            # Record in audit log
            log_audit_event(cur, actor_user_id, 'APPLICATION_STAGE_TRANSITION', 'job_application', int(app_id),
                            pre_state={'status': prev_stage}, post_state={'status': new_stage, 'notes': notes})

            conn.commit()
            cur.close()
            conn.close()

            self.send_json({
                'success': True,
                'message': f'Applicant successfully moved to {new_stage}!',
                'data': {'application_id': app_id, 'previous_stage': prev_stage, 'new_stage': new_stage}
            })
        except Exception as e:
            self.send_json({'success': False, 'error': str(e)}, 500)

    def handle_api_employer_download_resume(self, body):
        """Deducts 10 credits from wallet, inserts append-only wallet_transaction & download log"""
        try:
            org_id = body.get('organisation_id')
            candidate_id = body.get('candidate_id')
            actor_user_id = body.get('actor_user_id', 1)

            if not org_id or not candidate_id:
                self.send_json({'success': False, 'error': 'organisation_id and candidate_id are required'}, 400)
                return

            conn = db_config.get_connection()
            cur = conn.cursor(dictionary=True)

            # Check wallet balance
            cur.execute("SELECT id, current_credit_balance FROM wallet_account WHERE organisation_id = %s FOR UPDATE;", (int(org_id),))
            wallet = cur.fetchone()
            if not wallet or wallet['current_credit_balance'] < 10.00:
                self.send_json({'success': False, 'error': 'Insufficient wallet balance. Recharge credits to download profiles.'}, 402)
                cur.close()
                conn.close()
                return

            # Check candidate primary resume
            cur.execute("SELECT id FROM candidate_resume WHERE candidate_profile_id = %s LIMIT 1;", (int(candidate_id),))
            res = cur.fetchone()
            resume_id = res['id'] if res else 1

            new_balance = wallet['current_credit_balance'] - Decimal('10.00')

            # Deduct from wallet_account
            cur.execute("""
                UPDATE wallet_account 
                SET current_credit_balance = %s, updated_at = NOW(6)
                WHERE id = %s;
            """, (new_balance, wallet['id']))

            # Append-only transaction entry
            cur.execute("""
                INSERT INTO wallet_transaction (
                    uuid, wallet_account_id, transaction_type_code, transaction_amount,
                    balance_after_transaction, currency_code, transaction_description, transaction_timestamp
                ) VALUES (
                    UUID(), %s, 'DEBIT_PROFILE_DOWNLOAD', -10.00, %s, 'INR',
                    CONCAT('Resume download fee for candidate #', %s), NOW(6)
                );
            """, (wallet['id'], new_balance, str(candidate_id)))

            # Append-only download history log (Rule Group 10)
            cur.execute("""
                INSERT INTO candidate_profile_download_history (
                    downloader_user_id, downloader_organisation_id, candidate_profile_id,
                    candidate_resume_id, credit_deduction_amount, download_purpose, ip_address, downloaded_at
                ) VALUES (
                    %s, %s, %s, %s, 10.00, 'DIRECT_SOURCING', '127.0.0.1', NOW(6)
                );
            """, (actor_user_id, int(org_id), int(candidate_id), resume_id))

            log_audit_event(cur, actor_user_id, 'CANDIDATE_RESUME_DOWNLOADED', 'candidate_profile', int(candidate_id),
                            post_state={'credits_deducted': 10.0, 'new_balance': float(new_balance)})

            conn.commit()
            cur.close()
            conn.close()

            self.send_json({
                'success': True,
                'message': 'Resume downloaded successfully! 10 credits deducted from wallet.',
                'data': {'new_balance': float(new_balance)}
            })
        except Exception as e:
            self.send_json({'success': False, 'error': str(e)}, 500)

    def handle_api_employer_recharge_wallet(self, body):
        """Adds credits to employer wallet via append-only ledger"""
        try:
            org_id = body.get('organisation_id')
            credits_to_add = Decimal(str(body.get('credits', 500)))
            amount_inr = Decimal(str(body.get('amount_inr', 5000)))
            actor_user_id = body.get('actor_user_id', 1)

            conn = db_config.get_connection()
            cur = conn.cursor(dictionary=True)

            cur.execute("SELECT id, current_credit_balance FROM wallet_account WHERE organisation_id = %s FOR UPDATE;", (int(org_id),))
            wallet = cur.fetchone()
            if not wallet:
                # Create wallet account if missing
                cur.execute("INSERT INTO wallet_account (uuid, organisation_id, current_credit_balance) VALUES (UUID(), %s, 0.00);", (int(org_id),))
                wallet_id = cur.lastrowid
                current_bal = Decimal('0.00')
            else:
                wallet_id = wallet['id']
                current_bal = wallet['current_credit_balance']

            new_balance = current_bal + credits_to_add

            # Create payment order record
            cur.execute("""
                INSERT INTO payment_order (
                    uuid, organisation_id, initiated_by_user_id, idempotency_key,
                    order_amount, currency_code, order_purpose_code, payment_status_code, paid_at
                ) VALUES (
                    UUID(), %s, %s, UUID(), %s, 'INR', 'WALLET_RECHARGE', 'CAPTURED', NOW(6)
                );
            """, (int(org_id), actor_user_id, amount_inr))
            payment_order_id = cur.lastrowid

            # Update wallet balance
            cur.execute("UPDATE wallet_account SET current_credit_balance = %s, updated_at = NOW(6) WHERE id = %s;", (new_balance, wallet_id))

            # Append-only transaction entry
            cur.execute("""
                INSERT INTO wallet_transaction (
                    uuid, wallet_account_id, transaction_type_code, transaction_amount,
                    balance_after_transaction, currency_code, payment_order_id,
                    transaction_description, transaction_timestamp
                ) VALUES (
                    UUID(), %s, 'CREDIT_RECHARGE', %s, %s, 'INR', %s,
                    CONCAT('Instant prepaid credit recharge of ', %s, ' credits'), NOW(6)
                );
            """, (wallet_id, credits_to_add, new_balance, payment_order_id, str(credits_to_add)))

            log_audit_event(cur, actor_user_id, 'WALLET_RECHARGE_COMPLETED', 'wallet_account', wallet_id,
                            post_state={'credits_added': float(credits_to_add), 'new_balance': float(new_balance)})

            conn.commit()
            cur.close()
            conn.close()

            self.send_json({
                'success': True,
                'message': f'Wallet successfully recharged with {credits_to_add} credits!',
                'data': {'new_balance': float(new_balance)}
            })
        except Exception as e:
            self.send_json({'success': False, 'error': str(e)}, 500)

    def handle_api_employer_create_gig(self, body):
        try:
            org_id = body.get('organisation_id')
            title = body.get('gig_title')
            city_id = body.get('city_id', 1)
            pricing_model = body.get('pricing_model', 'FIXED_PRICE')
            budget = body.get('budget', 50000)
            start_date = body.get('start_date', '2026-11-01 09:00:00')
            end_date = body.get('end_date', '2026-11-15 18:00:00')
            desc = body.get('description', 'Short-term technical milestone delivery.')
            actor_user_id = body.get('actor_user_id', 1)

            conn = db_config.get_connection()
            cur = conn.cursor(dictionary=True)

            cur.execute("""
                INSERT INTO gig_request (
                    uuid, organisation_id, city_id, gig_title, gig_description,
                    pricing_model_code, budget_amount, budget_currency_code,
                    window_start_time, window_end_time, workers_needed_count,
                    gig_status_code, created_at, created_by
                ) VALUES (
                    UUID(), %s, %s, %s, %s, %s, %s, 'INR', %s, %s, 1, 'OPEN', NOW(6), %s
                );
            """, (int(org_id), int(city_id), title, desc, pricing_model, float(budget),
                  start_date, end_date, actor_user_id))
            gig_id = cur.lastrowid

            log_audit_event(cur, actor_user_id, 'GIG_REQUEST_PUBLISHED', 'gig_request', gig_id,
                            post_state={'title': title, 'budget': float(budget)})

            conn.commit()
            cur.close()
            conn.close()

            self.send_json({
                'success': True,
                'message': 'Gig project request published successfully!',
                'data': {'gig_id': gig_id}
            })
        except Exception as e:
            self.send_json({'success': False, 'error': str(e)}, 500)

    def handle_api_employer_accept_gig(self, body):
        """Accepts contractor bid, assigns gig, creates external handoff reference key"""
        try:
            gig_request_id = body.get('gig_request_id')
            worker_id = body.get('worker_id')
            agreed_payout = body.get('agreed_payout', 45000)
            actor_user_id = body.get('actor_user_id', 1)

            conn = db_config.get_connection()
            cur = conn.cursor(dictionary=True)

            cur.execute("SELECT window_start_time, window_end_time FROM gig_request WHERE id = %s;", (int(gig_request_id),))
            gr = cur.fetchone()
            if not gr:
                self.send_json({'success': False, 'error': 'Gig request not found'}, 404)
                cur.close()
                conn.close()
                return

            handoff_ref = f"FULFIL-EXT-{uuid.uuid4().hex[:12].upper()}"

            # Insert gig assignment
            cur.execute("""
                INSERT INTO gig_assignment (
                    uuid, gig_request_id, gig_worker_profile_id, external_handoff_reference_id,
                    assignment_status_code, scheduled_start_time, scheduled_end_time, agreed_payout_amount
                ) VALUES (
                    UUID(), %s, %s, %s, 'ASSIGNED', %s, %s, %s
                );
            """, (int(gig_request_id), int(worker_id), handoff_ref, gr['window_start_time'], gr['window_end_time'], float(agreed_payout)))
            assignment_id = cur.lastrowid

            # Create earnings reference record
            cur.execute("""
                INSERT INTO gig_earnings_reference (
                    gig_assignment_id, estimated_earnings, reconciled_earnings, reconciliation_status_code, last_synced_at
                ) VALUES (
                    %s, %s, 0.00, 'PENDING_FULFILMENT', NOW(6)
                );
            """, (assignment_id, float(agreed_payout)))

            # Update gig_request status
            cur.execute("UPDATE gig_request SET gig_status_code = 'ASSIGNED', updated_at = NOW(6) WHERE id = %s;", (int(gig_request_id),))

            log_audit_event(cur, actor_user_id, 'GIG_ASSIGNED_EXTERNAL_HANDOFF', 'gig_assignment', assignment_id,
                            post_state={'handoff_key': handoff_ref, 'payout': float(agreed_payout)})

            conn.commit()
            cur.close()
            conn.close()

            self.send_json({
                'success': True,
                'message': 'Contractor accepted! External fulfillment handoff key generated.',
                'data': {'assignment_id': assignment_id, 'handoff_key': handoff_ref}
            })
        except Exception as e:
            self.send_json({'success': False, 'error': str(e)}, 500)

    def handle_api_employer_wallet(self, params):
        try:
            org_id = params.get('org_id', ['1'])[0]
            conn = db_config.get_connection()
            cur = conn.cursor(dictionary=True)

            cur.execute("""
                SELECT id, current_credit_balance, currency_code
                FROM wallet_account WHERE organisation_id = %s;
            """, (int(org_id),))
            wallet = cur.fetchone()

            transactions = []
            if wallet:
                cur.execute("""
                    SELECT id, transaction_type_code, transaction_amount, balance_after_transaction,
                           transaction_description, transaction_timestamp
                    FROM wallet_transaction
                    WHERE wallet_account_id = %s
                    ORDER BY id DESC LIMIT 20;
                """, (wallet['id'],))
                transactions = cur.fetchall()

            cur.close()
            conn.close()
            self.send_json({
                'success': True,
                'data': {
                    'wallet': wallet or {'current_credit_balance': 0.0, 'currency_code': 'INR'},
                    'transactions': transactions
                }
            })
        except Exception as e:
            self.send_json({'success': False, 'error': str(e)}, 500)

    # =========================================================================
    # PORTAL 3: TALENTRA ADMIN APIS & GOVERNANCE
    # =========================================================================
    def handle_api_admin_organisations(self):
        try:
            conn = db_config.get_connection()
            cur = conn.cursor(dictionary=True)

            cur.execute("""
                SELECT 
                    o.id, o.uuid, o.legal_name, o.trade_name, o.verification_status_code,
                    o.created_at,
                    ov.identifier_type_code, ov.identifier_value_masked, ov.verification_status_code AS tax_status,
                    wa.current_credit_balance
                FROM organisation o
                LEFT JOIN organisation_verification ov ON ov.organisation_id = o.id
                LEFT JOIN wallet_account wa ON wa.organisation_id = o.id
                WHERE o.deleted_at IS NULL
                ORDER BY o.verification_status_code ASC, o.id DESC;
            """)
            orgs = cur.fetchall()

            cur.close()
            conn.close()
            self.send_json({'success': True, 'data': {'organisations': orgs}})
        except Exception as e:
            self.send_json({'success': False, 'error': str(e)}, 500)

    def handle_api_admin_verify_organisation(self, body):
        try:
            org_id = body.get('organisation_id')
            actor_user_id = body.get('actor_user_id', 1)

            conn = db_config.get_connection()
            cur = conn.cursor(dictionary=True)

            cur.execute("UPDATE organisation SET verification_status_code = 'VERIFIED', updated_at = NOW(6) WHERE id = %s;", (int(org_id),))
            cur.execute("UPDATE organisation_verification SET verification_status_code = 'VERIFIED', verified_at = NOW(6) WHERE organisation_id = %s;", (int(org_id),))

            log_audit_event(cur, actor_user_id, 'ORGANISATION_VERIFIED_BY_ADMIN', 'organisation', int(org_id),
                            post_state={'status': 'VERIFIED'})

            conn.commit()
            cur.close()
            conn.close()

            self.send_json({'success': True, 'message': 'Organisation compliance verification completed.'})
        except Exception as e:
            self.send_json({'success': False, 'error': str(e)}, 500)

    def handle_api_admin_sessions(self):
        try:
            conn = db_config.get_connection()
            cur = conn.cursor(dictionary=True)

            cur.execute("""
                SELECT 
                    us.id AS session_id, us.app_user_id, us.ip_address, us.session_start_time, us.last_activity_time,
                    us.is_active, u.email_address, ud.device_name, ud.device_type_code, ud.operating_system, ud.browser_name
                FROM user_session us
                INNER JOIN app_user u ON us.app_user_id = u.id
                INNER JOIN user_device ud ON us.user_device_id = ud.id
                WHERE us.is_active = TRUE
                ORDER BY us.last_activity_time DESC LIMIT 30;
            """)
            sessions = cur.fetchall()

            cur.close()
            conn.close()
            self.send_json({'success': True, 'data': {'sessions': sessions}})
        except Exception as e:
            self.send_json({'success': False, 'error': str(e)}, 500)

    def handle_api_admin_revoke_session(self, body):
        try:
            session_id = body.get('session_id')
            actor_user_id = body.get('actor_user_id', 1)
            reason = body.get('reason', 'Administrative compliance revocation')

            conn = db_config.get_connection()
            cur = conn.cursor(dictionary=True)

            cur.execute("""
                UPDATE user_session 
                SET is_active = FALSE, session_end_time = NOW(6), session_end_reason_code = 'REVOKED_BY_ADMIN'
                WHERE id = %s;
            """, (int(session_id),))

            # Insert into session_revocation_event
            cur.execute("""
                INSERT INTO session_revocation_event (
                    uuid, user_session_id, revoked_by_user_id, revocation_reason, revoked_at
                ) VALUES (
                    UUID(), %s, %s, %s, NOW(6)
                );
            """, (int(session_id), actor_user_id, reason))

            log_audit_event(cur, actor_user_id, 'USER_SESSION_REVOKED', 'user_session', int(session_id),
                            post_state={'reason': reason})

            conn.commit()
            cur.close()
            conn.close()

            self.send_json({'success': True, 'message': 'Active session terminated and auditable revocation event recorded.'})
        except Exception as e:
            self.send_json({'success': False, 'error': str(e)}, 500)

    def handle_api_admin_test_session_limit(self, body):
        """Tests stored procedure sp_authenticate_and_open_session for concurrency limit enforcement"""
        try:
            user_id = body.get('user_id', 1)
            conn = db_config.get_connection()
            cur = conn.cursor()

            fingerprint = f"fp_{uuid.uuid4().hex[:16]}"
            token_hash = f"tok_{uuid.uuid4().hex[:32]}"

            # Call stored procedure
            # (p_user_id, p_device_fingerprint, p_device_name, p_device_type, p_operating_system, p_browser_name, p_ip_address, p_user_agent, p_session_token_hash, @p_session_id, @p_status_code)
            cur.execute("""
                CALL sp_authenticate_and_open_session(
                    %s, %s, 'Demo Test Terminal', 'DESKTOP', 'Windows 11', 'Chrome 122',
                    '127.0.0.1', 'Mozilla/5.0 Demo Browser', %s, @p_session_id, @p_status_code
                );
            """, (user_id, fingerprint, token_hash))

            cur.execute("SELECT @p_session_id, @p_status_code;")
            session_id, status_code = cur.fetchone()

            conn.commit()
            cur.close()
            conn.close()

            self.send_json({
                'success': True,
                'data': {
                    'session_id': session_id,
                    'status_code': status_code,
                    'enforced_by': 'sp_authenticate_and_open_session (InnoDB Row Lock)'
                }
            })
        except Exception as e:
            self.send_json({'success': False, 'error': str(e)}, 500)

    # =========================================================================
    # EXISTING REUSED BENCHMARK & SCHEMA APIS
    # =========================================================================
    def handle_api_candidates(self, params):
        try:
            conn = db_config.get_connection()
            cur = conn.cursor(dictionary=True)

            role_id = params.get('role_id', [None])[0]
            city_id = params.get('city_id', [None])[0]
            min_exp = params.get('min_exp', [None])[0]
            search_query = params.get('q', [None])[0]
            blocked_org_id = params.get('blocked_org_id', [None])[0]

            query = """
                SELECT 
                    cp.id, cp.uuid, cp.display_name, cp.first_name, cp.last_name,
                    c.city_name, jr.role_name, cp.total_experience_months,
                    ROUND(cp.total_experience_months / 12, 1) AS experience_years,
                    cp.expected_salary, cp.salary_currency_code, cp.salary_disclosure_status,
                    cp.notice_period_days, cp.profile_completion_percentage,
                    u.email_address, CONCAT(u.country_dial_code, ' ', u.national_phone_number) AS phone,
                    (SELECT COUNT(*) FROM candidate_skill WHERE candidate_profile_id = cp.id) AS skills_count,
                    (SELECT GROUP_CONCAT(s.skill_name SEPARATOR ', ') 
                     FROM candidate_skill cs INNER JOIN skill s ON cs.skill_id = s.id 
                     WHERE cs.candidate_profile_id = cp.id LIMIT 4) AS top_skills,
                    (SELECT COUNT(*) FROM privacy_block_entry pbe 
                     WHERE pbe.blocker_candidate_user_id = u.id AND pbe.is_active = TRUE 
                       AND pbe.blocked_entity_type = 'ORGANISATION' AND pbe.blocked_target_id = %s) AS has_blocked_viewer
                FROM candidate_profile cp
                INNER JOIN app_user u ON cp.app_user_id = u.id
                LEFT JOIN city c ON cp.current_city_id = c.id
                LEFT JOIN job_role jr ON cp.current_job_role_id = jr.id
                WHERE cp.deleted_at IS NULL AND cp.is_actively_looking = TRUE
            """
            test_org_id = int(blocked_org_id) if (blocked_org_id and blocked_org_id.isdigit()) else 1
            query_args = [test_org_id]

            if role_id and role_id.isdigit():
                query += " AND cp.current_job_role_id = %s"
                query_args.append(int(role_id))

            if city_id and city_id.isdigit():
                query += " AND cp.current_city_id = %s"
                query_args.append(int(city_id))

            if min_exp and min_exp.isdigit():
                query += " AND cp.total_experience_months >= %s"
                query_args.append(int(min_exp) * 12)

            if search_query:
                query += " AND (cp.display_name LIKE %s OR u.email_address LIKE %s)"
                term = f"%{search_query}%"
                query_args.extend([term, term])

            apply_blocking = params.get('apply_privacy_blocking', ['false'])[0].lower() == 'true'
            if apply_blocking:
                query += """
                    AND NOT EXISTS (
                        SELECT 1 FROM privacy_block_entry pbe
                        WHERE pbe.blocker_candidate_user_id = u.id AND pbe.is_active = TRUE
                          AND pbe.blocked_entity_type = 'ORGANISATION' AND pbe.blocked_target_id = %s
                    )
                """
                query_args.append(test_org_id)

            query += " ORDER BY cp.profile_completion_percentage DESC, cp.total_experience_months DESC LIMIT 50;"

            cur.execute(query, tuple(query_args))
            candidates = cur.fetchall()

            cur.execute("SELECT id, role_name FROM job_role WHERE is_active = TRUE ORDER BY display_order;")
            roles = cur.fetchall()
            cur.execute("SELECT id, city_name FROM city WHERE is_active = TRUE ORDER BY display_order;")
            cities = cur.fetchall()
            cur.execute("SELECT id, trade_name FROM organisation WHERE deleted_at IS NULL ORDER BY trade_name;")
            organisations = cur.fetchall()

            cur.close()
            conn.close()
            self.send_json({
                'success': True,
                'data': {
                    'candidates': candidates,
                    'roles': roles,
                    'cities': cities,
                    'organisations': organisations,
                    'total_returned': len(candidates)
                }
            })
        except Exception as e:
            self.send_json({'success': False, 'error': str(e)}, 500)

    def handle_api_pipeline(self, params):
        try:
            conn = db_config.get_connection()
            cur = conn.cursor(dictionary=True)

            job_id = params.get('job_id', [None])[0]

            cur.execute("""
                SELECT 
                    jr.id, jr.uuid, jr.job_title, o.trade_name AS company_name, o.id AS organisation_id,
                    jr.positions_count, jr.positions_filled_count, jr.publish_state_code,
                    jr.minimum_salary, jr.maximum_salary, jr.open_date,
                    COUNT(ja.id) AS total_applicants,
                    SUM(CASE WHEN ja.application_status_code = 'APPLIED' THEN 1 ELSE 0 END) AS stage_applied,
                    SUM(CASE WHEN ja.application_status_code = 'SHORTLISTED' THEN 1 ELSE 0 END) AS stage_shortlisted,
                    SUM(CASE WHEN ja.application_status_code = 'INTERVIEWED' THEN 1 ELSE 0 END) AS stage_interviewed,
                    SUM(CASE WHEN ja.application_status_code = 'OFFERED' THEN 1 ELSE 0 END) AS stage_offered,
                    SUM(CASE WHEN ja.application_status_code = 'JOINED' THEN 1 ELSE 0 END) AS stage_joined,
                    SUM(CASE WHEN ja.application_status_code = 'REJECTED' THEN 1 ELSE 0 END) AS stage_rejected
                FROM job_requirement jr
                INNER JOIN organisation o ON jr.organisation_id = o.id
                LEFT JOIN job_application ja ON ja.job_requirement_id = jr.id
                WHERE jr.deleted_at IS NULL
                GROUP BY jr.id, jr.uuid, jr.job_title, o.trade_name, o.id, jr.positions_count, 
                         jr.positions_filled_count, jr.publish_state_code, jr.minimum_salary, jr.maximum_salary, jr.open_date
                ORDER BY jr.id ASC;
            """)
            jobs = cur.fetchall()

            applicants = []
            if job_id and job_id.isdigit():
                cur.execute("""
                    SELECT 
                        ja.id AS application_id, ja.candidate_profile_id, cp.display_name, cp.total_experience_months,
                        ROUND(cp.total_experience_months / 12, 1) AS experience_years,
                        c.city_name, ja.application_status_code, ja.match_score_percentage, ja.applied_at,
                        u.email_address
                    FROM job_application ja
                    INNER JOIN candidate_profile cp ON ja.candidate_profile_id = cp.id
                    INNER JOIN app_user u ON cp.app_user_id = u.id
                    LEFT JOIN city c ON cp.current_city_id = c.id
                    WHERE ja.job_requirement_id = %s
                    ORDER BY ja.match_score_percentage DESC, ja.applied_at DESC;
                """, (int(job_id),))
                applicants = cur.fetchall()

            cur.close()
            conn.close()
            self.send_json({
                'success': True,
                'data': {
                    'jobs': jobs,
                    'applicants': applicants
                }
            })
        except Exception as e:
            self.send_json({'success': False, 'error': str(e)}, 500)

    def handle_api_gigs(self):
        try:
            conn = db_config.get_connection()
            cur = conn.cursor(dictionary=True)

            cur.execute("""
                SELECT 
                    gr.id, gr.uuid, gr.gig_title, gr.gig_description, gr.pricing_model_code,
                    gr.budget_amount, gr.budget_currency_code, gr.window_start_time, gr.window_end_time,
                    gr.gig_status_code, o.trade_name AS company_name, c.city_name
                FROM gig_request gr
                INNER JOIN organisation o ON gr.organisation_id = o.id
                INNER JOIN city c ON gr.city_id = c.id
                WHERE gr.deleted_at IS NULL
                ORDER BY gr.id DESC;
            """)
            gig_requests = cur.fetchall()

            cur.execute("""
                SELECT 
                    gwp.id, gwp.headline, gwp.hourly_charge_rate, gwp.charge_currency_code,
                    gwp.overall_rating_average, gwp.completed_gigs_count, gwp.is_available_for_instant_dispatch,
                    cp.display_name, c.city_name, u.email_address
                FROM gig_worker_profile gwp
                INNER JOIN app_user u ON gwp.app_user_id = u.id
                INNER JOIN candidate_profile cp ON cp.app_user_id = u.id
                LEFT JOIN city c ON cp.current_city_id = c.id
                WHERE gwp.deleted_at IS NULL
                ORDER BY gwp.overall_rating_average DESC LIMIT 20;
            """)
            gig_workers = cur.fetchall()

            cur.execute("""
                SELECT 
                    ga.id, ga.external_handoff_reference_id, ga.assignment_status_code,
                    ga.scheduled_start_time, ga.scheduled_end_time, ga.agreed_payout_amount,
                    gr.gig_title, gwp.headline AS worker_headline, cp.display_name AS worker_name,
                    ger.reconciled_earnings, ger.reconciliation_status_code
                FROM gig_assignment ga
                INNER JOIN gig_request gr ON ga.gig_request_id = gr.id
                INNER JOIN gig_worker_profile gwp ON ga.gig_worker_profile_id = gwp.id
                INNER JOIN app_user u ON gwp.app_user_id = u.id
                INNER JOIN candidate_profile cp ON cp.app_user_id = u.id
                LEFT JOIN gig_earnings_reference ger ON ger.gig_assignment_id = ga.id
                ORDER BY ga.id DESC LIMIT 15;
            """)
            assignments = cur.fetchall()

            cur.close()
            conn.close()
            self.send_json({
                'success': True,
                'data': {
                    'gig_requests': gig_requests,
                    'gig_workers': gig_workers,
                    'assignments': assignments
                }
            })
        except Exception as e:
            self.send_json({'success': False, 'error': str(e)}, 500)

    def handle_api_benchmark_queries(self):
        query_list = []
        for idx, (title, sql) in enumerate(BENCHMARK_QUERIES, 1):
            query_list.append({
                'id': idx,
                'title': title,
                'sql': sql.strip()
            })
        self.send_json({'success': True, 'data': query_list})

    def handle_api_benchmark_run(self, body):
        try:
            query_id = body.get('query_id')
            if not query_id or query_id < 1 or query_id > len(BENCHMARK_QUERIES):
                self.send_json({'success': False, 'error': 'Invalid query ID'}, 400)
                return

            title, sql = BENCHMARK_QUERIES[query_id - 1]

            conn = db_config.get_connection()
            cur = conn.cursor()

            # Execute EXPLAIN
            cur.execute(f"EXPLAIN {sql}")
            explain_rows = cur.fetchall()
            explain_cols = [c[0] for c in cur.description]

            # Execute query and measure latency
            t0 = time.perf_counter()
            cur.execute(sql)
            rows = cur.fetchall()
            t1 = time.perf_counter()
            cols = [c[0] for c in cur.description]
            latency_ms = round((t1 - t0) * 1000.0, 3)

            cur.close()
            conn.close()

            self.send_json({
                'success': True,
                'data': {
                    'query_id': query_id,
                    'title': title,
                    'sql': sql,
                    'latency_ms': latency_ms,
                    'row_count': len(rows),
                    'columns': cols,
                    'rows': rows[:50],
                    'explain_columns': explain_cols,
                    'explain_rows': explain_rows
                }
            })
        except Exception as e:
            self.send_json({'success': False, 'error': str(e)}, 500)

    def handle_api_schema(self):
        try:
            conn = db_config.get_connection()
            cur = conn.cursor(dictionary=True)

            cur.execute("""
                SELECT 
                    TABLE_NAME AS table_name,
                    TABLE_TYPE AS table_type,
                    TABLE_ROWS AS approx_rows,
                    DATA_LENGTH AS data_bytes,
                    INDEX_LENGTH AS index_bytes,
                    TABLE_COMMENT AS table_comment
                FROM information_schema.TABLES
                WHERE TABLE_SCHEMA = 'talentra_db'
                ORDER BY TABLE_TYPE ASC, TABLE_NAME ASC;
            """)
            tables = cur.fetchall()

            cur.close()
            conn.close()
            self.send_json({'success': True, 'data': {'tables': tables, 'total_count': len(tables)}})
        except Exception as e:
            self.send_json({'success': False, 'error': str(e)}, 500)

    def handle_api_audit(self):
        try:
            conn = db_config.get_connection()
            cur = conn.cursor(dictionary=True)

            cur.execute("""
                SELECT 
                    id, actor_user_id, action_type, target_entity_name, target_entity_id,
                    ip_address, action_timestamp, pre_change_state, post_change_state
                FROM audit_log
                ORDER BY id DESC LIMIT 35;
            """)
            audit_events = cur.fetchall()

            cur.execute("""
                SELECT 
                    us.id, u.email_address, ud.device_name, ud.device_type_code,
                    us.ip_address, us.session_start_time, us.last_activity_time, us.is_active
                FROM user_session us
                INNER JOIN app_user u ON us.app_user_id = u.id
                INNER JOIN user_device ud ON us.user_device_id = ud.id
                WHERE us.is_active = TRUE
                ORDER BY us.last_activity_time DESC LIMIT 20;
            """)
            active_sessions = cur.fetchall()

            cur.close()
            conn.close()
            self.send_json({
                'success': True,
                'data': {
                    'audit_events': audit_events,
                    'active_sessions': active_sessions
                }
            })
        except Exception as e:
            self.send_json({'success': False, 'error': str(e)}, 500)

def start_server(port=5000):
    server_address = ('', port)
    httpd = ThreadingHTTPServer(server_address, TalentraRequestHandler)
    print("================================================================")
    print("🚀 Talentra Interactive Multi-Portal Platform Server")
    print(f"👉 Local URL: http://localhost:{port}")
    print("Connected to MySQL Database: talentra_db (InnoDB)")
    print("3 Active Portals: Candidate, Employer ATS, Talentra Admin")
    print("Press Ctrl+C to terminate server")
    print("================================================================")
    try:
        httpd.serve_forever()
    except KeyboardInterrupt:
        print("\nStopping server ...")
        httpd.server_close()

if __name__ == '__main__':
    port = int(sys.argv[1]) if len(sys.argv) > 1 and sys.argv[1].isdigit() else 5000
    start_server(port)
