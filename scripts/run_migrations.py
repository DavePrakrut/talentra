"""
Migration Runner for Talentra Database
Executes all SQL migration files in strict dependency order against MySQL 8.0.
"""

import os
import sys
import subprocess
from db_config import DB_CONFIG, get_mysql_cli_command

# Force UTF-8 stdout on Windows
if sys.platform == 'win32':
    try:
        sys.stdout.reconfigure(encoding='utf-8')
    except Exception:
        pass

SQL_DIR = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), 'sql')

MIGRATION_FILES = [
    '00_init_database.sql',
    '01_master_data.sql',
    '02_administration_and_rbac.sql',
    '03_organisation_and_account.sql',
    '04_candidate_profile.sql',
    '05_jobs_and_applications.sql',
    '06_gig_marketplace.sql',
    '07_licences_seats_devices.sql',
    '08_sourcing_and_consultants.sql',
    '09_subscriptions_wallet_billing.sql',
    '10_notifications_and_community.sql',
    '11_analytics_reporting_marts.sql',
    '12_views_and_security_controls.sql',
    '13_triggers_and_integrity_rules.sql',
    '15_seed_reference_data.sql'
]

def run_migrations():
    mysql_cmd = get_mysql_cli_command()
    reset_mode = '--reset' in sys.argv or '--fresh' in sys.argv

    print("================================================================")
    print("Running Talentra Database Migrations")
    print(f"Target Host: {DB_CONFIG['host']}:{DB_CONFIG['port']}")
    print(f"Database:    {DB_CONFIG['database']}")
    print(f"MySQL CLI:   {mysql_cmd}")
    if reset_mode:
        print("Mode:        FRESH RESET (Dropping existing database first)")
    print("================================================================")

    if reset_mode:
        print("[RESET] Dropping and recreating database ... ", end='', flush=True)
        drop_cmd = [
            mysql_cmd,
            f"--host={DB_CONFIG['host']}",
            f"--port={DB_CONFIG['port']}",
            f"--user={DB_CONFIG['user']}",
            f"--password={DB_CONFIG['password']}",
            "-e", f"DROP DATABASE IF EXISTS {DB_CONFIG['database']}; CREATE DATABASE {DB_CONFIG['database']} CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci;"
        ]
        subprocess.run(drop_cmd, check=True, capture_output=True)
        print("SUCCESS")

    for file_name in MIGRATION_FILES:
        file_path = os.path.join(SQL_DIR, file_name)
        if not os.path.exists(file_path):
            print(f"[FAIL] Missing file: {file_name}")
            sys.exit(1)

        print(f"[APPLYING] {file_name} ... ", end='', flush=True)

        cmd = [
            mysql_cmd,
            f"--host={DB_CONFIG['host']}",
            f"--port={DB_CONFIG['port']}",
            f"--user={DB_CONFIG['user']}",
            f"--password={DB_CONFIG['password']}",
            "--default-character-set=utf8mb4"
        ]

        try:
            with open(file_path, 'r', encoding='utf-8') as f:
                res = subprocess.run(cmd, stdin=f, capture_output=True, text=True, check=False)
            
            if res.returncode == 0:
                print("SUCCESS")
            else:
                print("FAILED")
                print(f"Error output:\n{res.stderr}")
                sys.exit(res.returncode)
        except Exception as e:
            print(f"[ERROR] Exception: {e}")
            sys.exit(1)

    print("================================================================")
    print(f"All {len(MIGRATION_FILES)} migrations completed successfully!")
    print("================================================================")

if __name__ == '__main__':
    run_migrations()
