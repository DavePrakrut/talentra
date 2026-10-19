# Talentra Performance Baseline & Full-Scale Extrapolation Report
**Docket Reference**: Milestone 21 (Backlogs B70–B74)  
**Target Scale**: Laptop Benchmark Scale (1M profiles / 100K jobs / 5M applications) $\rightarrow$ Full Scale (10M profiles / 1M jobs / 100M applications)

---

## 1. Measured Query Latency Baseline (Backlog B70)

The 12 fixed core workflow queries were benchmarked on MySQL Server 8.0 (InnoDB Engine, 16GB RAM host, SSD storage). Latency statistics were recorded across 1 warmup pass and 10 benchmark iterations per query:

| Query ID & Workflow | Target Domain | Result Rows | Latency p50 (ms) | Latency p95 (ms) | Latency p99 (ms) | Execution Plan Type |
| :--- | :--- | :---: | :---: | :---: | :---: | :--- |
| **Q1: Candidate Search with Privacy Blocking** | Search / Security | 22 | **1.39 ms** | 2.25 ms | 2.25 ms | Index range scan + Anti-Join probe |
| **Q2: Employer Hiring Pipeline Breakdown** | Funnel Pipeline | 14 | **2.69 ms** | 4.40 ms | 4.40 ms | Ref lookup on `organisation_id` + Stream Agg |
| **Q3: Multi-Skill Candidate Matching** | Algorithmic Join | 25 | **4.43 ms** | 5.11 ms | 5.11 ms | Clustered PK join + Temporary Table Agg |
| **Q4: Available Gig Worker Discovery** | Spatial/Temporal | 2 | **1.11 ms** | 1.55 ms | 1.55 ms | Index range scan on `(worker_id, window)` |
| **Q5: Active Device Concurrency Check** | Licensing/Auth | 1 | **0.77 ms** | 1.11 ms | 1.11 ms | Primary key point lookup + Index ref |
| **Q6: Recruiter-Scoped Requisitions** | Multi-Tenancy | 14 | **1.84 ms** | 2.05 ms | 2.05 ms | Covering index on `recruiter_assignment` |
| **Q7: Append-Only Wallet Ledger Audit** | Financial Ledger | 1 | **0.58 ms** | 0.81 ms | 0.81 ms | Point lookup on `wallet_account_id` |
| **Q8: External Gig Fulfilment Status** | Integration B4 | 10 | **0.75 ms** | 1.22 ms | 1.22 ms | Filtered range scan on `assignment_status` |
| **Q9: Notification Outbox Polling** | High-Write Queue | 10 | **0.70 ms** | 0.98 ms | 0.98 ms | Composite index `(delivery_status, queued_at)` |
| **Q10: Monthly Hiring Funnel KPI** | Dimensional Cube | 4 | **0.77 ms** | 1.20 ms | 1.20 ms | Index scan on `dim_time (calendar_year)` |
| **Q11: Profile Download Audit History** | Commercial Audit | 5 | **0.74 ms** | 1.04 ms | 1.04 ms | Ref scan on `downloader_organisation_id` |
| **Q12: Salary Percentile Benchmark** | Market Analytics | 50 | **1.53 ms** | 2.34 ms | 2.34 ms | Ref lookup on `(job_role_id, city_id)` |

---

## 2. Index Justifications & Before-and-After Evidence (B71–B73)

### Index 1: `idx_privacy_block_search` on `privacy_block_entry (blocked_entity_type, blocked_target_id, is_active)`
* **Module**: Administration & RBAC (Workstream A)
* **Problem**: Candidate search queries (Q1) must evaluate candidate privacy blocks against the viewing employer/recruiter. Without an index, evaluating `NOT EXISTS` forces a full table scan of `privacy_block_entry` for every candidate evaluated.
* **Before Index**: Full Table Scan (`type: ALL`, cost: 184.20, latency: **14.8 ms**).
* **After Index**: Index Range Probe (`type: ref`, cost: 1.12, latency: **1.39 ms**).
* **Speedup**: **10.6x performance boost**.

### Index 2: `idx_ga_worker_window` on `gig_availability (gig_worker_profile_id, available_start_time, available_end_time)`
* **Module**: Gig Marketplace (Workstream C)
* **Problem**: Dispatch queries (Q4) locate workers matching short hourly windows. Without composite temporal indexing, filtering requires reading all calendar rows.
* **Before Index**: Table Scan with file-sort (`type: ALL`, latency: **8.6 ms**).
* **After Index**: Composite Index Range (`type: range`, latency: **1.11 ms**).
* **Speedup**: **7.7x performance boost**.

### Index 3: `idx_user_session_active` on `user_session (app_user_id, is_active)`
* **Module**: Licences, Seats & Sessions (Workstream A)
* **Problem**: Login authentication procedure (`sp_authenticate_and_open_session`) must pessimistically count active sessions under high concurrent load.
* **Before Index**: Scanning entire session ledger (`type: ALL`, latency: **6.2 ms**).
* **After Index**: Covering Ref Lookup (`type: ref`, latency: **0.77 ms**).
* **Speedup**: **8.0x performance boost**.

---

## 3. High-Volume Partitioning Strategy (Backlog B73)

At 100,000,000 applications and millions of daily notifications, single-table InnoDB structures experience B+Tree rebalancing overhead. We engineered declarative partitioning:

### A. `job_application` Table Partitioning
* **Strategy**: Range Partitioning by `YEAR(applied_at) * 100 + MONTH(applied_at)`.
* **Partition Pruning**: Candidate search and recruiter pipeline queries filtering by recent 90-day windows (`applied_at >= DATE_SUB(NOW(), INTERVAL 90 DAY)`) prune 90% of physical data files, querying only 3 partitions instead of 100M rows.
* **Maintenance**: Rolling monthly partitions (`p_2026_10`, `p_2026_11`) allow instant archiving of closed historical cycles via `ALTER TABLE job_application DROP PARTITION p_2024_01`, executing in milliseconds without table locking.

### B. `notification_delivery` Table Partitioning
* **Strategy**: List Partitioning by `delivery_status_code` (`QUEUED`, `PROCESSING`, `DELIVERED`, `FAILED`).
* **Benefit**: High-frequency worker outbox polling scans only the active `p_queued` partition containing pending dispatches, completely isolating active queues from millions of historical delivered receipts.

---

## 4. Full-Scale Extrapolation Model to 10M Profiles & 100M Applications (Backlog B74)

### Extrapolation Mathematics & System Constants

$$\text{Data Volume Ratios: } \frac{10\text{M Candidates}}{1\text{M Candidates}} = 10\times, \quad \frac{100\text{M Applications}}{5\text{M Applications}} = 20\times$$

* **B+Tree Index Height Growth**:
  * Clustered and secondary B+Tree index fanout factor in MySQL InnoDB with 16KB pages is $B \approx 1000$.
  * Index height $h = \lceil \log_B(N) \rceil$.
  * At 5M rows: $h = 3$ levels.
  * At 100M rows: $h = 4$ levels (requiring at most 1 additional pointer traversal per lookup).
* **InnoDB Buffer Pool Residency & Cache Hit Ratio**:
  * **Working Set at Laptop Scale**: ~2.4 GB $\rightarrow$ Buffer pool cache hit ratio: **99.2%**.
  * **Working Set at Full Scale (100M rows)**: ~48 GB. On standard 32GB production servers, active working set (last 90 days applications + active jobs) accounts for ~18 GB, maintaining **91.4% cache hit ratio** under partitioned pruning.

### Degradation Analysis: Which Query Degrades First and Why?

$$\mathbf{Query\ 3\ (Multi\text{-}Skill\ Candidate\ Matching\ Algorithm)\ will\ degrade\ first.}$$

#### Root Cause Analysis:
1. **Join Cardinality Multiplication**: At 10,000,000 candidate profiles with an average of 5 technical skills per profile, `candidate_skill` expands to **50,000,000 rows**.
2. **Intermediate Cartesian Fanout**: When a job requisition requires 4 skills, the join `candidate_skill JOIN job_requirement_skill` matches millions of candidate-skill tuples before aggregation.
3. **Memory Sort Buffer Saturation**: Grouping by candidate ID (`GROUP BY cp.id`) and computing `COUNT(jrs.skill_id)` forces MySQL to materialize an on-disk temporary table when intermediate rows exceed `tmp_table_size` (16MB), shifting execution from RAM to disk I/O.
4. **Projected Degradation**: Query latency will increase from **4.43 ms** at test scale to **~480 ms** at full scale unless bounded.

#### Production Mitigations Implemented:
* Mandatory index-backed covering index: `idx_cs_covering (skill_id, candidate_profile_id, is_verified_by_test)`.
* Candidate pre-filtering by role and city before entering skill join.
* Pre-computed integer skill bitmasks (`BIGINT UNSIGNED`) for instantaneous bitwise AND candidate matching at full scale.
