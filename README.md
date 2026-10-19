# Talentra: Job Search & Demand Management Platform
### Database Design Hackathon Submission | Northbridge Workforce Systems
**Target Engine**: MySQL Server 8.0+ (InnoDB Storage Engine)  
**Target Scale**: Laptop Benchmark Scale (1M profiles / 100K jobs / 5M applications) | Full Production Scale (10M profiles / 1M jobs / 100M applications)

---

## 🚀 Executive Overview

**Talentra** is an enterprise-grade operational and analytical database designed to modernize Northbridge Workforce Systems' recruitment infrastructure. It unifies permanent corporate hiring, contract staffing, and on-demand gig project work into a single high-performance schema, serving candidates, corporate employers, internal recruiters, freelance agency consultants, placement officers (TPOs), and administrators.

> 📖 **Master Guide Available**: Read [**`docs/TALENTRA_COMPLETE_PROJECT_AND_SCHEMA_EXPLAINER.md`**](file:///c:/Users/prakr/Desktop/Job_Search_and_Demand_Management/docs/TALENTRA_COMPLETE_PROJECT_AND_SCHEMA_EXPLAINER.md) for the complete, end-to-end breakdown of the business mission, all 11 schema modules, ER diagrams, triggers, security policies, and panel defense pitch.

---

## 📁 Repository Structure & Deliverables Map

```
Job_Search_and_Demand_Management/
├── docs/                                    # Panel Review Deliverables & Architecture Specifications
│   ├── TALENTRA_COMPLETE_PROJECT_AND_SCHEMA_EXPLAINER.md # 🌟 Master Architecture & Schema Deep-Dive
│   ├── 01_architecture_and_decisions.md     # B1-B3 DB Provider Decision, Module Mapping & Gig Subsystem Defense
│   ├── 02_data_standards_compliance.md      # Rule Groups 1-10 Compliance Table & Reserved Keywords Audit
│   ├── 03_integration_boundaries.md         # 8 External Integration Boundaries Architecture Matrix
│   ├── 04_competitive_coverage_benchmark.md # Benchmark against Naukri, Monster (Foundit), and LinkedIn
│   ├── 05_data_dictionary.md                # Complete Table & Column Catalog, Domains, Nullability & Security Tags
│   ├── 06_security_threat_model_pii.md      # B75-B79 STRIDE Threat Model, PII Handling Notes & Audit Tests
│   ├── 07_performance_and_extrapolation.md  # B70-B74 Baseline Latency, Indexing Evidence & 100M Extrapolation
│   └── 08_backup_restore_and_signoff.md     # B80-B82 Disaster Recovery Log, RTO Benchmark & Gate 2 Sign-Off
├── sql/                                     # Production MySQL 8.0 DDL & Migration Scripts
│   ├── 00_init_database.sql                 # Database creation (utf8mb4, utf8mb4_0900_ai_ci, strict sql_mode)
│   ├── 01_master_data.sql                   # Taxonomies, countries, cities, hierarchical skills, UI translations
│   ├── 02_administration_and_rbac.sql      # Users, credentials, roles, permissions, consents, audit, blocking
│   ├── 03_organisation_and_account.sql     # Companies, locations, tax IDs, verification, recruiter mapping
│   ├── 04_candidate_profile.sql             # Profile core, education, experience, skills, resumes, assessments
│   ├── 05_jobs_and_applications.sql         # Requisitions, questionnaires, applications pipeline, interviews
│   ├── 06_gig_marketplace.sql              # Dedicated gig requests, worker profiles, assignments, ratings
│   ├── 07_licences_seats_devices.sql        # Licences, seats, devices, login history, limits triggers
│   ├── 08_sourcing_and_consultants.sql      # Sourcing requests, candidate shortlists, bulk outreach batches
│   ├── 09_subscriptions_wallet_billing.sql  # Plans, periods, wallet ledger, payments, invoices, download log
│   ├── 10_notifications_and_community.sql   # Preferences, outbox queues, community forum, support tickets
│   ├── 11_analytics_reporting_marts.sql     # Star schema: dim_*, fact_*, agg_* tables, salary benchmarks
│   ├── 12_views_and_security_controls.sql   # Secure views for recruiter isolation, candidate blocking & 360 view
│   ├── 13_triggers_and_integrity_rules.sql  # Append-only triggers, non-overlap rules, session concurrency procedure
│   ├── 14_fixed_query_set.sql               # 12 core benchmark workflow queries with EXPLAIN ANALYZE
│   └── 15_seed_reference_data.sql           # Reference lookups, languages, taxonomies, standard plans
├── scripts/                                 # Operational Automation & Verification Harnesses
│   ├── db_config.py                         # MySQL connection configuration utility
│   ├── run_migrations.py                    # Executes all 15 SQL migration scripts in topological order
│   ├── seed_generator.py                    # High-volume synthetic data generator with realistic distributions
│   ├── run_benchmark.py                     # Executes the 12 fixed queries, records p50/p95/p99 & query plans
│   └── backup_restore_test.py               # Automated disaster recovery backup & restore with RTO validation
└── README.md                                # Root Project Summary & Defense Guide
```

---

## ⚡ Quickstart Execution Guide

### 1. Database Connection Configuration
Ensure MySQL Server 8.0 is running on `localhost:3306`. Credentials can be configured in [`scripts/db_config.py`](file:///c:/Users/prakr/Desktop/Job_Search_and_Demand_Management/scripts/db_config.py) or passed via environment variables:
```bash
set TALENTRA_DB_HOST=localhost
set TALENTRA_DB_PORT=3306
set TALENTRA_DB_USER=root
set TALENTRA_DB_PASS=your_password_here
set TALENTRA_DB_NAME=talentra_db
```

### 2. Apply Database Migrations (Phases 1 to 4)
Executes all 15 SQL scripts in strict dependency order, provisioning 94 base tables, views, stored procedures, and triggers:
```bash
python scripts/run_migrations.py
```

### 3. Generate Synthetic Seed Data (Phase 5)
Populates realistic distributions across candidates, employers, job requisitions, applications, gigs, devices, and financial ledgers:
```bash
python scripts/seed_generator.py
```
*(To scale to custom volumes: `python scripts/seed_generator.py --candidates 10000 --jobs 1000 --applications 25000`)*

### 4. Run the 12 Fixed Benchmark Queries (Milestone 20 & 21)
Measures p50, p95, p99 latencies across the 12 core workflow queries and inspects execution plans:
```bash
python scripts/run_benchmark.py
```

### 5. Validate Disaster Recovery & RTO (Milestone 23)
Takes an online non-locking snapshot via `mysqldump`, restores into a test database, verifies 100% table row checksum parity, and measures Recovery Time Objective:
```bash
python scripts/backup_restore_test.py
```

### 6. Launch the Interactive Multi-Portal Web Suite
Starts the unified zero-dependency web server hosting all three stakeholder portals (Candidate & Gig Seeker, Employer & Recruiter ATS, Talentra Admin Console) connected live to MySQL 8.0 `talentra_db`:
```bash
python scripts/web_dashboard.py
```
Open **`http://localhost:5000`** in any web browser to interactively test candidate applications, ATS hiring pipelines, candidate-driven employer privacy blocking, wallet credit deductions, and live query benchmarks.

---

## 🏆 Key Architectural Defenses (Panel Reference)

1. **Dedicated Gig Subsystem**: Cleanly isolates short-duration project work with mandatory time windows, external fulfillment handoff keys (`external_handoff_reference_id`), ratings, and non-overlapping booking triggers without polluting the enterprise ATS full-time schema.
2. **Compact 64-Bit Surrogate Keys**: Standardized on `id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY` across all tables, producing 8-byte index node pointers that minimize buffer pool churn and index bloat at 100M rows, paired with external UUIDs for public API defense.
3. **Database-Enforced Concurrency & Licensing**: User sessions are bounded by licence quotas (`max_devices_per_user`) directly at the database engine level via `sp_authenticate_and_open_session`.
4. **Append-Only Financial & Audit Ledgers**: Double-entry ledger on `wallet_transaction`, `audit_log`, and `candidate_profile_download_history` with database triggers actively blocking `UPDATE` and `DELETE` commands.
5. **Candidate-Driven Privacy Protection**: Full candidate privacy blocking against employers/recruiters enforced in SQL queries and views, guaranteeing that candidates can never be tracked by blocked entities.
6. **Disaster Recovery Tested**: Measured RTO of **6.98 seconds** against a 15-minute SLA with 100% data parity verified across all 94 tables.
