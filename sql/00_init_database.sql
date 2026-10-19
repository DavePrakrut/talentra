-- ============================================================================
-- Talentra Database Initialization Script
-- Engine: MySQL Server 8.0+ (InnoDB Storage Engine)
-- Character Set: utf8mb4 | Collation: utf8mb4_0900_ai_ci
-- ============================================================================

CREATE DATABASE IF NOT EXISTS talentra_db
  CHARACTER SET utf8mb4
  COLLATE utf8mb4_0900_ai_ci;

USE talentra_db;

-- Set session parameters for strict SQL compliance and deterministic datetime handling
SET SESSION sql_mode = 'STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION';
SET SESSION time_zone = '+00:00';
