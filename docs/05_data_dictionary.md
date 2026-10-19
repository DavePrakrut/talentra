# Talentra Data Dictionary & Domain Governance Catalog
**Docket Reference**: Section 4 (Data Elements & Coverage), Section 5 (Rule Groups 3, 5, 6)

Every column in the Talentra schema conforms to standard domain constraints, has an explicit nullability justification, and is tagged with a security classification:
* **`[PUBLIC]`**: Freely queryable by anonymous guests or verified users without restriction.
* **`[INTERNAL]`**: Available only to authenticated staff and the owning corporate organization.
* **`[PERSONAL]`**: Identifies a candidate/individual person; governed by strict GDPR/DPDP access controls and privacy blocking filters.
* **`[SENSITIVE]`**: High-risk financial tokens, tax numbers, authentication hashes, and national identifiers; requires masking, tokenization, or salted cryptographic hashing.

---

## 1. Module 1: Master Data & Taxonomies

| Entity & Column Name | Data Type & Domain | Nullable? | Nullability Justification | Security Class |
| :--- | :--- | :---: | :--- | :---: |
| **`country.id`** | `BIGINT UNSIGNED AUTO_INCREMENT` | No | Surrogate Primary Key | `[PUBLIC]` |
| `country.iso_alpha2_code` | `CHAR(2)` (ISO 3166-1 alpha-2) | No | Canonical ISO country code | `[PUBLIC]` |
| `country.country_name` | `VARCHAR(150)` | No | Full official country name | `[PUBLIC]` |
| `country.country_dial_code`| `VARCHAR(5)` (E.164 dial code) | No | International dial code (e.g. `+91`) | `[PUBLIC]` |
| **`city.id`** | `BIGINT UNSIGNED AUTO_INCREMENT` | No | Surrogate Primary Key | `[PUBLIC]` |
| `city.city_name` | `VARCHAR(150)` | No | Municipality name | `[PUBLIC]` |
| `city.latitude` | `DECIMAL(10,8)` | Yes | Optional spatial enrichment | `[PUBLIC]` |
| `city.longitude` | `DECIMAL(11,8)` | Yes | Optional spatial enrichment | `[PUBLIC]` |
| **`skill.id`** | `BIGINT UNSIGNED AUTO_INCREMENT` | No | Surrogate Primary Key | `[PUBLIC]` |
| `skill.skill_code` | `VARCHAR(50)` | No | Canonical uppercase identifier | `[PUBLIC]` |
| `skill.skill_name` | `VARCHAR(150)` | No | Human-readable skill label | `[PUBLIC]` |
| `skill.is_trending` | `BOOLEAN` | No | Algorithmic trending flag | `[PUBLIC]` |
| **`ui_translation.id`**| `BIGINT UNSIGNED AUTO_INCREMENT` | No | Surrogate Primary Key | `[PUBLIC]` |
| `ui_translation.translation_key` | `VARCHAR(150)` | No | UI resource localization key | `[PUBLIC]` |
| `ui_translation.language_code` | `CHAR(2)` | No | ISO 639-1 language code | `[PUBLIC]` |
| `ui_translation.translated_text`| `TEXT` | No | Localized UTF-8 string | `[PUBLIC]` |

---

## 2. Module 2: Administration, Identity & RBAC

| Entity & Column Name | Data Type & Domain | Nullable? | Nullability Justification | Security Class |
| :--- | :--- | :---: | :--- | :---: |
| **`app_user.id`** | `BIGINT UNSIGNED AUTO_INCREMENT` | No | Surrogate Primary Key | `[INTERNAL]` |
| `app_user.email_address` | `VARCHAR(254)` | No | Unique lowercased account identifier | `[PERSONAL]` |
| `app_user.country_dial_code`| `VARCHAR(5)` | No | Contact country prefix | `[PERSONAL]` |
| `app_user.national_phone_number` | `VARCHAR(15)` | No | E.164 national subscriber number | `[PERSONAL]` |
| `app_user.locked_until` | `DATETIME(6)` | Yes | NULL if account is in normal standing | `[INTERNAL]` |
| **`user_credential.id`** | `BIGINT UNSIGNED AUTO_INCREMENT` | No | Surrogate Primary Key | `[SENSITIVE]` |
| `user_credential.password_hash` | `VARCHAR(255)` | No | Argon2id cryptographic password hash | `[SENSITIVE]` |
| `user_credential.password_salt` | `VARCHAR(128)` | No | Cryptographic salt per account | `[SENSITIVE]` |
| **`privacy_block_entry.id`** | `BIGINT UNSIGNED AUTO_INCREMENT` | No | Surrogate Primary Key | `[PERSONAL]` |
| `privacy_block_entry.blocker_candidate_user_id` | `BIGINT UNSIGNED` | No | Candidate exercising blocking right | `[PERSONAL]` |
| `privacy_block_entry.blocked_entity_type` | `VARCHAR(50)` | No | Discriminator (`ORGANISATION` / `RECRUITER`) | `[PERSONAL]` |
| `privacy_block_entry.blocked_target_id` | `BIGINT UNSIGNED` | No | Target entity ID | `[PERSONAL]` |
| **`audit_log.id`** | `BIGINT UNSIGNED AUTO_INCREMENT` | No | Surrogate Primary Key | `[INTERNAL]` |
| `audit_log.action_type` | `VARCHAR(100)` | No | Auditable event verb | `[INTERNAL]` |
| `audit_log.pre_change_state` | `JSON` | Yes | NULL on pure insert actions | `[INTERNAL]` |

---

## 3. Module 3: Organisation, Accounts & Recruiter Mapping

| Entity & Column Name | Data Type & Domain | Nullable? | Nullability Justification | Security Class |
| :--- | :--- | :---: | :--- | :---: |
| **`organisation.id`** | `BIGINT UNSIGNED AUTO_INCREMENT` | No | Surrogate Primary Key | `[PUBLIC]` |
| `organisation.legal_name` | `VARCHAR(200)` | No | Official corporate legal title | `[PUBLIC]` |
| `organisation.trade_name` | `VARCHAR(150)` | No | Commercial trading brand name | `[PUBLIC]` |
| `organisation.parent_organisation_id` | `BIGINT UNSIGNED` | Yes | NULL for top-level root enterprises | `[INTERNAL]` |
| **`organisation_verification.id`** | `BIGINT UNSIGNED AUTO_INCREMENT` | No | Surrogate Primary Key | `[INTERNAL]` |
| `organisation_verification.identifier_value_masked` | `VARCHAR(50)` | No | Masked tax string (e.g. `27AAAAA****A1Z5`) | `[INTERNAL]` |
| `organisation_verification.identifier_hash` | `VARCHAR(128)` | No | Salted SHA-256 hash for deduplication | `[SENSITIVE]` |
| **`recruiter_assignment.id`** | `BIGINT UNSIGNED AUTO_INCREMENT` | No | Surrogate Primary Key | `[INTERNAL]` |
| `recruiter_assignment.effective_from_date` | `DATE` | No | Role inception date | `[INTERNAL]` |
| `recruiter_assignment.effective_to_date` | `DATE` | Yes | NULL indicates currently active assignment | `[INTERNAL]` |

---

## 4. Module 4: Candidate Profile Core

| Entity & Column Name | Data Type & Domain | Nullable? | Nullability Justification | Security Class |
| :--- | :--- | :---: | :--- | :---: |
| **`candidate_profile.id`** | `BIGINT UNSIGNED AUTO_INCREMENT` | No | Surrogate Primary Key | `[PERSONAL]` |
| `candidate_profile.first_name` | `VARCHAR(75)` | No | Given name | `[PERSONAL]` |
| `candidate_profile.last_name` | `VARCHAR(75)` | Yes | NULL for mononymic persons | `[PERSONAL]` |
| `candidate_profile.date_of_birth` | `DATE` | Yes | Optional field protected from age bias | `[PERSONAL]` |
| `candidate_profile.current_salary` | `DECIMAL(14,2)` | Yes | NULL when candidate opts for `UNDISCLOSED` | `[PERSONAL]` |
| `candidate_profile.expected_salary` | `DECIMAL(14,2)` | Yes | NULL when candidate opts for `UNDISCLOSED` | `[PERSONAL]` |
| `candidate_profile.salary_disclosure_status` | `VARCHAR(50)` | No | Explicit state: `DISCLOSED`, `UNDISCLOSED`, `NOT_APPLICABLE` | `[PERSONAL]` |
| `candidate_profile.notice_period_days` | `INT UNSIGNED` | No | Availability lead time | `[PERSONAL]` |
| `candidate_profile.profile_completion_percentage` | `DECIMAL(5,2)` | No | Quality index between 0.00 and 100.00 | `[INTERNAL]` |
| **`candidate_education.id`** | `BIGINT UNSIGNED AUTO_INCREMENT` | No | Surrogate Primary Key | `[PERSONAL]` |
| `candidate_education.grade_percentage_or_gpa` | `DECIMAL(5,2)` | Yes | Optional based on university grading scale | `[PERSONAL]` |
| **`candidate_work_experience.id`** | `BIGINT UNSIGNED AUTO_INCREMENT` | No | Surrogate Primary Key | `[PERSONAL]` |
| `candidate_work_experience.end_date` | `DATE` | Yes | NULL indicates currently employed role | `[PERSONAL]` |

---

## 5. Module 5: Jobs & Applications Pipeline

| Entity & Column Name | Data Type & Domain | Nullable? | Nullability Justification | Security Class |
| :--- | :--- | :---: | :--- | :---: |
| **`job_requirement.id`** | `BIGINT UNSIGNED AUTO_INCREMENT` | No | Surrogate Primary Key | `[PUBLIC]` |
| `job_requirement.job_title` | `VARCHAR(150)` | No | Requisition position title | `[PUBLIC]` |
| `job_requirement.positions_count` | `INT UNSIGNED` | No | Total authorized openings (>= 1) | `[PUBLIC]` |
| `job_requirement.minimum_salary` | `DECIMAL(14,2)` | Yes | NULL when salary band is confidential | `[PUBLIC]` |
| `job_requirement.maximum_salary` | `DECIMAL(14,2)` | Yes | NULL when salary band is confidential | `[PUBLIC]` |
| `job_requirement.close_date` | `DATE` | Yes | NULL indicates indefinite / rolling hiring | `[PUBLIC]` |
| **`job_application.id`** | `BIGINT UNSIGNED AUTO_INCREMENT` | No | Surrogate Primary Key | `[INTERNAL]` |
| `job_application.application_status_code` | `VARCHAR(50)` | No | Stage: `APPLIED`, `SHORTLISTED`, `INTERVIEWED`, etc. | `[INTERNAL]` |
| `job_application.match_score_percentage` | `DECIMAL(5,2)` | No | Algorithmic fit score | `[INTERNAL]` |
| `job_application.shortlisted_at` | `DATETIME(6)` | Yes | NULL until candidate advances to shortlisted | `[INTERNAL]` |
| `job_application.rejection_reason_code` | `VARCHAR(100)` | Yes | NULL unless application status is `REJECTED` | `[INTERNAL]` |

---

## 6. Module 6: Gig Marketplace Subsystem

| Entity & Column Name | Data Type & Domain | Nullable? | Nullability Justification | Security Class |
| :--- | :--- | :---: | :--- | :---: |
| **`gig_worker_profile.id`** | `BIGINT UNSIGNED AUTO_INCREMENT` | No | Surrogate Primary Key | `[PUBLIC]` |
| `gig_worker_profile.hourly_charge_rate` | `DECIMAL(10,2)` | No | Public contractor charge rate (> 0.00) | `[PUBLIC]` |
| `gig_worker_profile.overall_rating_average` | `DECIMAL(3,2)` | No | Rolling average between 0.00 and 5.00 | `[PUBLIC]` |
| **`gig_request.id`** | `BIGINT UNSIGNED AUTO_INCREMENT` | No | Surrogate Primary Key | `[PUBLIC]` |
| `gig_request.budget_amount` | `DECIMAL(14,2)` | No | Allocated project budget (> 0.00) | `[PUBLIC]` |
| `gig_request.window_start_time` | `DATETIME(6)` | No | Mandatory gig delivery inception | `[PUBLIC]` |
| `gig_request.window_end_time` | `DATETIME(6)` | No | Mandatory gig delivery termination | `[PUBLIC]` |
| **`gig_assignment.id`** | `BIGINT UNSIGNED AUTO_INCREMENT` | No | Surrogate Primary Key | `[INTERNAL]` |
| `gig_assignment.external_handoff_reference_id`| `VARCHAR(100)`| No | Correlation key for external fulfilment | `[INTERNAL]` |
| `gig_assignment.agreed_payout_amount` | `DECIMAL(14,2)` | No | Agreed contractor compensation | `[INTERNAL]` |

---

## 7. Module 7: Licences, Seats, Devices & Sessions

| Entity & Column Name | Data Type & Domain | Nullable? | Nullability Justification | Security Class |
| :--- | :--- | :---: | :--- | :---: |
| **`subscription_licence.id`** | `BIGINT UNSIGNED AUTO_INCREMENT` | No | Surrogate Primary Key | `[INTERNAL]` |
| `subscription_licence.max_users` | `INT UNSIGNED` | No | Maximum licensed seat quota (> 0) | `[INTERNAL]` |
| `subscription_licence.max_devices_per_user` | `INT UNSIGNED` | No | Hardware device quota per user (> 0) | `[INTERNAL]` |
| **`user_device.id`** | `BIGINT UNSIGNED AUTO_INCREMENT` | No | Surrogate Primary Key | `[INTERNAL]` |
| `user_device.device_fingerprint_hash` | `VARCHAR(128)` | No | Salted SHA-256 hardware identifier | `[INTERNAL]` |
| **`user_session.id`** | `BIGINT UNSIGNED AUTO_INCREMENT` | No | Surrogate Primary Key | `[INTERNAL]` |
| `user_session.session_token_hash` | `VARCHAR(128)` | No | Salted SHA-256 session token | `[SENSITIVE]` |
| `user_session.session_end_time` | `DATETIME(6)` | Yes | NULL while session is active | `[INTERNAL]` |

---

## 8. Module 9: Subscriptions, Wallet & Billing

| Entity & Column Name | Data Type & Domain | Nullable? | Nullability Justification | Security Class |
| :--- | :--- | :---: | :--- | :---: |
| **`wallet_account.id`** | `BIGINT UNSIGNED AUTO_INCREMENT` | No | Surrogate Primary Key | `[INTERNAL]` |
| `wallet_account.current_credit_balance` | `DECIMAL(14,2)` | No | Reconciled ledger balance | `[INTERNAL]` |
| **`wallet_transaction.id`** | `BIGINT UNSIGNED AUTO_INCREMENT` | No | Surrogate Primary Key | `[INTERNAL]` |
| `wallet_transaction.transaction_amount` | `DECIMAL(14,2)` | No | Positive (credit) or negative (debit) | `[INTERNAL]` |
| `wallet_transaction.balance_after_transaction` | `DECIMAL(14,2)` | No | Post-transaction snapshot | `[INTERNAL]` |
| `wallet_transaction.original_compensating_transaction_id`| `BIGINT UNSIGNED`| Yes | Populated only on ledger correction | `[INTERNAL]` |
| **`payment_order.id`** | `BIGINT UNSIGNED AUTO_INCREMENT` | No | Surrogate Primary Key | `[INTERNAL]` |
| `payment_order.idempotency_key` | `VARCHAR(128)` | No | Unique transaction deduplication nonce | `[INTERNAL]` |
| `payment_order.gateway_order_reference_id` | `VARCHAR(100)` | Yes | Populated upon gateway checkout initiation | `[SENSITIVE]` |
| **`candidate_profile_download_history.id`** | `BIGINT UNSIGNED AUTO_INCREMENT` | No | Surrogate Primary Key | `[INTERNAL]` |
| `candidate_profile_download_history.credit_deduction_amount` | `DECIMAL(10,2)` | No | Immutable units deducted | `[INTERNAL]` |
