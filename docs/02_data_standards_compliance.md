# Talentra Data Standards & Domain Rules Compliance Matrix
**Docket Reference**: Section 5 (Rule Groups 1 to 10) & Section 7 Module Design Checklist  
**Target Engine**: MySQL Server 8.0 (InnoDB Engine)

---

## 1. Formal Rule Compliance Table

Before panel submission, every rule group must be evaluated for compliance, with deviations explicitly justified.

| Rule Group | Description | Design Complies? | Deviation with Technical Reason |
| :--- | :--- | :---: | :--- |
| **Rule Group 1: Naming Conventions** | `snake_case` for all tables/columns; singular nouns; PK named `id`; FKs named `<referenced_table>_id`; no reserved words; index names `idx_table_column`, unique constraints `uq_table_column`. | **Complies** | None. Strict adherence. All table names singular (`candidate_profile`, `job_requirement`, `gig_request`). Zero reserved keywords used as identifiers. |
| **Rule Group 2: Keys & Constraints** | Surrogate PK on every entity (64-bit integer); natural keys as unique constraints; FK database constraints with explicit ON UPDATE / ON DELETE; CHECK constraints for business rules; concurrency/licence limits enforced in DB; device limits enforced at login. | **Complies** | None. Standardized on `id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY` across all tables, companion `uuid CHAR(36) UNIQUE`. Concurrency & device limits enforced via pessimistic locking (`SELECT ... FOR UPDATE`) inside login stored procedures. |
| **Rule Group 3: Standard Domains** | Strict domains for Person name (text 150), Email (text 254 lowercase unique), Phone (E.164 + country), Money (`DECIMAL` + currency code), Coordinates (precision + source), Lookup tables with translations for enumerations. | **Complies** | None. Money fields use `DECIMAL(14,2)` + `currency_code CHAR(3)`. Dates/timestamps in UTC (`DATETIME(6)`). All enumerations backed by lookup tables with localization support. |
| **Rule Group 4: Audit & Lifecycle** | Business tables carry `created_at`, `created_by`, `updated_at`, `updated_by`. Classification into soft vs hard delete. Soft delete uses `deleted_at`. Audit records append-only. Retention rules defined. | **Complies** | None. Universal metadata columns implemented on all business entities. Triggers block `UPDATE`/`DELETE` on `audit_log`, `wallet_transaction`, and download history. |
| **Rule Group 5: Nullability & Unknown Values** | Every nullable column justified. Distinct handling for unknown vs not applicable. No sentinel values (no 0, 'NA', empty string for missing). | **Complies** | None. All nullable columns documented in Data Dictionary with business justification. Explicit state flags differentiate undisclosed vs not applicable values. |
| **Rule Group 6: Sensitive Data Classification** | Every column tagged as `Public`, `Internal`, `Personal`, or `Sensitive`. Masking/tokenization/encryption applied to sensitive fields. | **Complies** | None. Full 4-tier data classification tags in Data Dictionary. National IDs tokenized; password credentials hashed with Argon2id/BCrypt + salt; payment tokens stored instead of raw card numbers. |
| **Rule Group 7: Multilingual Data** | UTF-8 end-to-end (`utf8mb4`). UI strings stored by translation key with fallback. User content stored in source language with language recorded. | **Complies** | None. Full database initialized with `CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci`. Dedicated `ui_translation` table with language codes (`en`, `es`, `fr`, `hi`, `ar`, etc.) and default fallback. |
| **Rule Group 8: Naming of Physical Objects** | Partitions, views, and materialized views follow stated naming patterns. Analytical objects prefixed (`dim_`, `fact_`, `agg_`). | **Complies** | None. Partitions follow `p_YYYY_MM`, views use `v_`, analytical dimensional tables use `dim_`, facts use `fact_`, aggregate rollups use `agg_`. |
| **Reserved Keyword Check** | No engine reserved words used as identifiers across MySQL 8.0 and PostgreSQL. | **Complies** | None. Audited against MySQL 8.0 and PostgreSQL reserved keyword lists. Avoided words like `user` (`app_user`), `role` (`user_role`), `status` (`status_code`), `order` (`payment_order`), `key` (`lookup_key`), `rank` (`rank_order`). |
| **Rule Group 9: Licensing, Devices & Sessions** | Max users & devices per user stored as positive integers with CHECK constraints. Sessions <= device limit. Active sessions tracked; revocation auditable. | **Complies** | None. `CHECK (max_users > 0)` and `CHECK (max_devices_per_user > 0)`. Login trigger/procedure enforces session count. Session revocation logged in `audit_log`. |
| **Rule Group 10: Money, Subscriptions & History** | Append-only payment and wallet ledgers. Corrections recorded as new compensating entries. Non-overlapping subscription periods enforced. Download/view history append-only with actor, subject, timestamp, credits. | **Justified Deviation** | **Engine Adaptation**: MySQL 8.0 does not support PostgreSQL `EXCLUDE USING gist`. Non-overlapping subscription periods and non-overlapping gig worker booking windows are strictly enforced using **deterministic database triggers** (`BEFORE INSERT`/`BEFORE UPDATE`) with pessimistic locking, raising an SQLSTATE `45000` exception if an overlap is detected. |

---

## 2. Engine Reserved Keywords Audit Matrix

To guarantee strict compliance with Rule 1, identifiers were vetted against MySQL 8.0 and ANSI SQL / PostgreSQL reserved keyword lists:

| Intended Concept | Prohibited Reserved Keyword | Production Schema Identifier Used | Rationale |
| :--- | :--- | :--- | :--- |
| System User | `USER`, `USERS` | `app_user` | `USER` is a core SQL reserved keyword in both MySQL and PostgreSQL. |
| Access Role | `ROLE`, `ROLES` | `role_definition` / `user_role` | `ROLE` is a reserved keyword in MySQL 8.0 and SQL-99. |
| Permission Group | `GROUP`, `GROUPS` | `permission_group` | `GROUP` is a reserved clause in `GROUP BY`. |
| Translation Key | `KEY`, `KEYS` | `lookup_key` / `translation_key` | `KEY` is a reserved keyword in MySQL DDL. |
| Lifecycle Status | `STATUS` | `status_code` / `application_status` | `STATUS` is reserved or contextual in multiple engines. |
| Commercial Order | `ORDER` | `payment_order` / `sort_order` | `ORDER` is a reserved clause in `ORDER BY`. |
| Window Function Rank | `RANK` | `rank_order` / `display_order` | `RANK()` is a MySQL 8.0 window function keyword. |
| Work Condition | `CONDITION` | `condition_expression` | `CONDITION` is a MySQL reserved word in stored procedures. |
| Time Window | `INTERVAL` | `interval_duration` / `window_range` | `INTERVAL` is a temporal arithmetic keyword in MySQL. |
| Skill Match | `MATCH` | `match_score` / `match_percentage` | `MATCH` is a full-text search reserved keyword (`MATCH() AGAINST()`). |
| Record Rows | `ROW`, `ROWS` | `row_count` / `row_sequence` | `ROW` and `ROWS` are window framing reserved keywords in MySQL 8.0. |

---

## 3. Justification of Standard Domains & Nullability (Rule Groups 3 & 5)

### Standard Domain Specifications

```sql
-- 1. Identifier Domain
id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY
uuid CHAR(36) NOT NULL UNIQUE DEFAULT (UUID())

-- 2. Person Name Domain
full_name VARCHAR(150) NOT NULL
first_name VARCHAR(75) NOT NULL
last_name VARCHAR(75) NULL -- Justification: Mononymic individuals in several cultures have no surname

-- 3. Email Domain
email_address VARCHAR(254) NOT NULL -- RFC 5321 maximum email length
CONSTRAINT uq_app_user_email UNIQUE (email_address)

-- 4. Phone Domain
country_dial_code VARCHAR(5) NOT NULL -- E.g. '+91', '+1', '+44'
national_phone_number VARCHAR(15) NOT NULL -- E.164 subscriber number up to 15 digits
phone_e164 VARCHAR(20) GENERATED ALWAYS AS (CONCAT(country_dial_code, national_phone_number)) STORED

-- 5. Money Domain
monetary_amount DECIMAL(14,2) NOT NULL DEFAULT 0.00
currency_code CHAR(3) NOT NULL DEFAULT 'INR' -- ISO 4217 3-letter currency code

-- 6. Date Range Check Constraints
CONSTRAINT chk_job_date_range CHECK (close_date IS NULL OR close_date >= open_date)
CONSTRAINT chk_salary_range CHECK (maximum_salary IS NULL OR maximum_salary >= minimum_salary)
```

### Nullability Policy & Differentiating Missing Data
* **Unknown vs Not Applicable**:
  * If a candidate chooses not to disclose their current salary, `salary_disclosure_status` is set to `'UNDISCLOSED'`, while `current_salary` is `NULL`.
  * For an unpaid internship or volunteer project, `salary_disclosure_status` is set to `'NOT_APPLICABLE'`, and `current_salary` is `NULL`.
  * Storing zero (`0.00`) is strictly reserved for genuinely zero compensation (e.g. uncompensated volunteer work).
* **No Sentinel Text Values**: The schema strictly forbids inserting sentinel strings such as `'NA'`, `'N/A'`, `'NONE'`, or empty strings `''` to represent missing or unpopulated data. Missing values must be stored as explicit `NULL` with a documented nullable justification.
