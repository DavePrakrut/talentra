"""
Talentra Database Configuration & Connection Utility
Targets MySQL Server 8.0 on localhost with InnoDB storage engine.
"""

import os
import mysql.connector
from mysql.connector import errorcode

DB_CONFIG = {
    'host': os.environ.get('TALENTRA_DB_HOST', 'localhost'),
    'port': int(os.environ.get('TALENTRA_DB_PORT', 3306)),
    'user': os.environ.get('TALENTRA_DB_USER', 'root'),
    'password': os.environ.get('TALENTRA_DB_PASS', 'your_password_here'),
    'database': os.environ.get('TALENTRA_DB_NAME', 'talentra_db'),
    'charset': 'utf8mb4',
    'collation': 'utf8mb4_0900_ai_ci',
    'autocommit': True,
    'use_pure': True
}

def get_connection(include_database=True):
    config = DB_CONFIG.copy()
    if not include_database:
        config.pop('database', None)
    try:
        conn = mysql.connector.connect(**config)
        return conn
    except mysql.connector.Error as err:
        if err.errno == errorcode.ER_ACCESS_DENIED_ERROR:
            raise ConnectionError("Invalid MySQL username or password.")
        elif err.errno == errorcode.ER_BAD_DB_ERROR:
            raise ConnectionError(f"Database {config.get('database')} does not exist.")
        else:
            raise ConnectionError(f"MySQL Connection Error: {err}")

def get_mysql_cli_command():
    """Returns path to mysql.exe for executing complex DDL scripts containing DELIMITER."""
    possible_paths = [
        r'C:\Program Files\MySQL\MySQL Server 8.0\bin\mysql.exe',
        'mysql'
    ]
    for p in possible_paths:
        if os.path.exists(p) or p == 'mysql':
            return p
    return 'mysql'
