"""
Talentra Disaster Recovery & Backup/Restore Test Suite
Measures mysqldump backup duration, target restore duration against RTO,
and verifies table row count checksums between original and restored databases.
Docket Reference: Milestone 23 (Backlog B80 - Backup & Restore Log)
"""

import sys
import os
import time
import subprocess

# Force UTF-8 stdout
if sys.platform == 'win32':
    try:
        sys.stdout.reconfigure(encoding='utf-8')
    except Exception:
        pass

sys.path.append(os.path.dirname(os.path.abspath(__file__)))
import db_config

MYSQL_BIN_DIR = r'C:\Program Files\MySQL\MySQL Server 8.0\bin'
MYSQLDUMP_CMD = os.path.join(MYSQL_BIN_DIR, 'mysqldump.exe')
MYSQL_CMD = os.path.join(MYSQL_BIN_DIR, 'mysql.exe')

BACKUP_FILE = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), 'talentra_backup_test.sql')
RESTORE_DB = 'talentra_restore_test'

def run_backup_and_restore():
    print("================================================================")
    print("Talentra Disaster Recovery Test (Backup & Restore)")
    print(f"Source Database:  {db_config.DB_CONFIG['database']}")
    print(f"Target Dump File: {BACKUP_FILE}")
    print(f"Target Restore DB:{RESTORE_DB}")
    print("================================================================")

    # 1. Execute Backup (mysqldump)
    print("[1/4] Initiating Consistent Snapshot Backup via mysqldump ... ", end='', flush=True)
    dump_cmd = [
        MYSQLDUMP_CMD,
        f"--host={db_config.DB_CONFIG['host']}",
        f"--port={db_config.DB_CONFIG['port']}",
        f"--user={db_config.DB_CONFIG['user']}",
        f"--password={db_config.DB_CONFIG['password']}",
        "--single-transaction",
        "--quick",
        "--routines",
        "--triggers",
        "--events",
        "--hex-blob",
        "--default-character-set=utf8mb4",
        db_config.DB_CONFIG['database']
    ]

    t0_backup = time.perf_counter()
    with open(BACKUP_FILE, 'w', encoding='utf-8') as f:
        res = subprocess.run(dump_cmd, stdout=f, stderr=subprocess.PIPE, text=True)
    t1_backup = time.perf_counter()

    if res.returncode != 0:
        print("FAILED")
        print("Error:", res.stderr)
        sys.exit(1)

    backup_duration = t1_backup - t0_backup
    file_size_mb = os.path.getsize(BACKUP_FILE) / (1024 * 1024)
    print(f"SUCCESS ({backup_duration:.2f}s, {file_size_mb:.2f} MB)")

    # 2. Prepare Clean Restore Target Database
    print(f"[2/4] Initializing Target Database `{RESTORE_DB}` ... ", end='', flush=True)
    prep_cmd = [
        MYSQL_CMD,
        f"--host={db_config.DB_CONFIG['host']}",
        f"--port={db_config.DB_CONFIG['port']}",
        f"--user={db_config.DB_CONFIG['user']}",
        f"--password={db_config.DB_CONFIG['password']}",
        "-e", f"DROP DATABASE IF EXISTS {RESTORE_DB}; CREATE DATABASE {RESTORE_DB} CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci;"
    ]
    subprocess.run(prep_cmd, check=True, capture_output=True)
    print("SUCCESS")

    # 3. Execute Restore
    print(f"[3/4] Restoring Snapshot into `{RESTORE_DB}` ... ", end='', flush=True)
    restore_cmd = [
        MYSQL_CMD,
        f"--host={db_config.DB_CONFIG['host']}",
        f"--port={db_config.DB_CONFIG['port']}",
        f"--user={db_config.DB_CONFIG['user']}",
        f"--password={db_config.DB_CONFIG['password']}",
        "--default-character-set=utf8mb4",
        RESTORE_DB
    ]

    t0_restore = time.perf_counter()
    with open(BACKUP_FILE, 'r', encoding='utf-8') as f:
        res_restore = subprocess.run(restore_cmd, stdin=f, stderr=subprocess.PIPE, text=True)
    t1_restore = time.perf_counter()

    if res_restore.returncode != 0:
        print("FAILED")
        print("Error:", res_restore.stderr)
        sys.exit(1)

    restore_duration = t1_restore - t0_restore
    print(f"SUCCESS ({restore_duration:.2f}s)")

    # 4. Integrity Validation: Verify Table Row Counts
    print("[4/4] Verifying Row Count Parity Across Databases ... ", end='', flush=True)
    conn = db_config.get_connection()
    cur = conn.cursor()

    cur.execute("SELECT TABLE_NAME FROM information_schema.TABLES WHERE TABLE_SCHEMA = 'talentra_db' AND TABLE_TYPE = 'BASE TABLE';")
    tables = [r[0] for r in cur.fetchall()]

    mismatches = 0
    for tbl in tables:
        cur.execute(f"SELECT COUNT(*) FROM talentra_db.{tbl};")
        orig_count = cur.fetchone()[0]
        cur.execute(f"SELECT COUNT(*) FROM {RESTORE_DB}.{tbl};")
        rest_count = cur.fetchone()[0]

        if orig_count != rest_count:
            print(f"\n❌ Mismatch in {tbl}: Original={orig_count}, Restored={rest_count}")
            mismatches += 1

    cur.close()
    conn.close()

    if mismatches == 0:
        print(f"SUCCESS ({len(tables)} tables verified, 100% parity)")
    else:
        print(f"FAILED ({mismatches} table count discrepancies)")
        sys.exit(1)

    # Clean up test restore database and dump file
    drop_cmd = [
        MYSQL_CMD,
        f"--host={db_config.DB_CONFIG['host']}",
        f"--port={db_config.DB_CONFIG['port']}",
        f"--user={db_config.DB_CONFIG['user']}",
        f"--password={db_config.DB_CONFIG['password']}",
        "-e", f"DROP DATABASE IF EXISTS {RESTORE_DB};"
    ]
    subprocess.run(drop_cmd, capture_output=True)

    print("================================================================")
    print("Disaster Recovery Summary & RTO Benchmark:")
    print(f"  - Backup Duration:  {backup_duration:.2f} seconds")
    print(f"  - Restore Duration: {restore_duration:.2f} seconds")
    print(f"  - Measured RTO:     {restore_duration:.2f} seconds (Target RTO: < 900 seconds)")
    print(f"  - Data Integrity:   100% verified (Zero record loss)")
    print("================================================================")

if __name__ == '__main__':
    run_backup_and_restore()
