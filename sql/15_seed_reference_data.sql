-- ============================================================================
-- Module 15: Master Reference Seed Data
-- Deliverables: Foundational taxonomies, lookups, UI translations, and standard plans
-- Compliance: Rule Groups 1, 3, 7
-- ============================================================================

USE talentra_db;

-- 1. Seed Currencies
INSERT INTO currency_code_lookup (currency_code, currency_name, currency_symbol, is_active, sort_order) VALUES
('INR', 'Indian Rupee', '₹', TRUE, 1),
('USD', 'United States Dollar', '$', TRUE, 2),
('EUR', 'Euro', '€', TRUE, 3),
('GBP', 'British Pound', '£', TRUE, 4)
ON DUPLICATE KEY UPDATE currency_name = VALUES(currency_name);

-- 2. Seed Employment Types
INSERT INTO employment_type_lookup (lookup_code, display_name, is_active, sort_order) VALUES
('PERMANENT_FULL_TIME', 'Permanent Full-Time', TRUE, 1),
('CONTRACT_CORP_TO_CORP', 'Contract (C2C)', TRUE, 2),
('CONTRACT_W2', 'Contract (Direct)', TRUE, 3),
('APPRENTICESHIP', 'Apprentice', TRUE, 4),
('CAMPUS_FRESHER', 'Campus & Fresher Hiring', TRUE, 5),
('GIG_FREELANCE', 'Gig / On-Demand Project', TRUE, 6)
ON DUPLICATE KEY UPDATE display_name = VALUES(display_name);

-- 3. Seed Work Modes
INSERT INTO work_mode_lookup (lookup_code, display_name, is_active, sort_order) VALUES
('ON_SITE', 'On-Site', TRUE, 1),
('HYBRID', 'Hybrid (2-3 days office)', TRUE, 2),
('REMOTE', 'Fully Remote', TRUE, 3)
ON DUPLICATE KEY UPDATE display_name = VALUES(display_name);

-- 4. Seed Countries
INSERT INTO country (id, iso_alpha2_code, iso_alpha3_code, country_name, country_dial_code, default_currency_code, display_order) VALUES
(1, 'IN', 'IND', 'India', '+91', 'INR', 1),
(2, 'US', 'USA', 'United States', '+1', 'USD', 2),
(3, 'GB', 'GBR', 'United Kingdom', '+44', 'GBP', 3),
(4, 'DE', 'DEU', 'Germany', '+49', 'EUR', 4),
(5, 'SG', 'SGP', 'Singapore', '+65', 'SGD', 5)
ON DUPLICATE KEY UPDATE country_name = VALUES(country_name);

-- 5. Seed States / Provinces
INSERT INTO state_province (id, country_id, state_code, state_name, display_order) VALUES
(1, 1, 'KA', 'Karnataka', 1),
(2, 1, 'MH', 'Maharashtra', 2),
(3, 1, 'DL', 'Delhi NCR', 3),
(4, 1, 'TS', 'Telangana', 4),
(5, 1, 'TN', 'Tamil Nadu', 5),
(6, 2, 'CA', 'California', 6),
(7, 2, 'NY', 'New York', 7),
(8, 3, 'ENG', 'England', 8)
ON DUPLICATE KEY UPDATE state_name = VALUES(state_name);

-- 6. Seed Cities
INSERT INTO city (id, state_province_id, city_name, latitude, longitude, display_order) VALUES
(1, 1, 'Bengaluru', 12.97159870, 77.59456270, 1),
(2, 2, 'Mumbai', 19.07609000, 72.87742600, 2),
(3, 2, 'Pune', 18.52043030, 73.85674370, 3),
(4, 3, 'New Delhi', 28.61393910, 77.20902120, 4),
(5, 4, 'Hyderabad', 17.38504400, 78.48667100, 5),
(6, 5, 'Chennai', 13.08268020, 80.27071840, 6),
(7, 6, 'San Francisco', 37.77492950, -122.41941550, 7),
(8, 7, 'New York City', 40.71277530, -74.00597280, 8),
(9, 8, 'London', 51.50735090, -0.12775830, 9)
ON DUPLICATE KEY UPDATE city_name = VALUES(city_name);

-- 7. Seed Spoken Languages
INSERT INTO spoken_language (id, iso_639_1_code, iso_639_2_code, language_name, native_script_name, is_ui_supported) VALUES
(1, 'en', 'eng', 'English', 'English', TRUE),
(2, 'hi', 'hin', 'Hindi', 'हिन्दी', TRUE),
(3, 'es', 'spa', 'Spanish', 'Español', TRUE),
(4, 'fr', 'fra', 'French', 'Français', TRUE),
(5, 'de', 'deu', 'German', 'Deutsch', TRUE),
(6, 'ja', 'jpn', 'Japanese', '日本語', FALSE),
(7, 'ar', 'ara', 'Arabic', 'العربية', FALSE)
ON DUPLICATE KEY UPDATE language_name = VALUES(language_name);

-- 8. Seed Multilingual UI Translations (Rule Group 7)
INSERT INTO ui_translation (translation_key, language_code, translated_text, fallback_text) VALUES
('btn_apply_job', 'en', 'Apply Now', 'Apply Now'),
('btn_apply_job', 'hi', 'अभी आवेदन करें', 'Apply Now'),
('btn_apply_job', 'es', 'Postularse ahora', 'Apply Now'),
('btn_post_gig', 'en', 'Post a Gig Requirement', 'Post a Gig Requirement'),
('btn_post_gig', 'hi', 'गिग आवश्यकता पोस्ट करें', 'Post a Gig Requirement'),
('lbl_profile_completion', 'en', 'Profile Completion Score', 'Profile Completion Score'),
('lbl_profile_completion', 'hi', 'प्रोफ़ाइल पूर्णता स्कोर', 'Profile Completion Score')
ON DUPLICATE KEY UPDATE translated_text = VALUES(translated_text);

-- 9. Seed Skill Categories
INSERT INTO skill_category (id, category_code, category_name, category_description, display_order) VALUES
(1, 'SOFTWARE_ENGINEERING', 'Software Engineering & Programming', 'Core backend, frontend, and systems languages', 1),
(2, 'DATA_AND_AI', 'Data Science & Artificial Intelligence', 'Analytics, machine learning, and big data', 2),
(3, 'CLOUD_AND_DEVOPS', 'Cloud & DevOps Infrastructure', 'SRE, containerization, and cloud platforms', 3),
(4, 'PRODUCT_DESIGN', 'Product Management & UI/UX', 'Product roadmap, wireframing, and user research', 4),
(5, 'SALES_MARKETING', 'Sales & Demand Generation', 'B2B enterprise sales and digital marketing', 5)
ON DUPLICATE KEY UPDATE category_name = VALUES(category_name);

-- 10. Seed Skills
INSERT INTO skill (id, skill_category_id, skill_code, skill_name, is_trending, display_order) VALUES
(1, 1, 'PYTHON', 'Python', TRUE, 1),
(2, 1, 'JAVA', 'Java', FALSE, 2),
(3, 1, 'JAVASCRIPT', 'JavaScript', TRUE, 3),
(4, 1, 'TYPESCRIPT', 'TypeScript', TRUE, 4),
(5, 1, 'SQL', 'SQL & Database Design', TRUE, 5),
(6, 1, 'GO', 'Golang', TRUE, 6),
(7, 2, 'MACHINE_LEARNING', 'Machine Learning', TRUE, 7),
(8, 2, 'DEEP_LEARNING', 'Deep Learning & LLMs', TRUE, 8),
(9, 2, 'DATA_ANALYSIS', 'Data Analysis & Pandas', TRUE, 9),
(10, 3, 'DOCKER', 'Docker & Containerization', TRUE, 10),
(11, 3, 'KUBERNETES', 'Kubernetes Orchestration', TRUE, 11),
(12, 3, 'AWS', 'Amazon Web Services (AWS)', TRUE, 12),
(13, 4, 'PRODUCT_MANAGEMENT', 'Product Management', FALSE, 13),
(14, 4, 'FIGMA_DESIGN', 'Figma UI/UX Prototyping', TRUE, 14),
(15, 5, 'ENTERPRISE_SALES', 'B2B Enterprise Sourcing', FALSE, 15)
ON DUPLICATE KEY UPDATE skill_name = VALUES(skill_name);

-- 11. Seed Educational Qualifications
INSERT INTO educational_qualification (id, qualification_code, qualification_name, qualification_level, display_order) VALUES
(1, 'BTECH_CS', 'Bachelor of Technology in Computer Science', 'BACHELORS', 1),
(2, 'BTECH_IT', 'Bachelor of Technology in Information Technology', 'BACHELORS', 2),
(3, 'BCA', 'Bachelor of Computer Applications', 'BACHELORS', 3),
(4, 'MTECH_CS', 'Master of Technology in Computer Science', 'MASTERS', 4),
(5, 'MCA', 'Master of Computer Applications', 'MASTERS', 5),
(6, 'MBA', 'Master of Business Administration', 'MASTERS', 6),
(7, 'PHD_CS', 'Doctor of Philosophy in Computer Science', 'DOCTORATE', 7)
ON DUPLICATE KEY UPDATE qualification_name = VALUES(qualification_name);

-- 12. Seed Industry Sectors
INSERT INTO industry_sector (id, industry_code, industry_name, display_order) VALUES
(1, 'IT_SERVICES', 'Information Technology & Software Services', 1),
(2, 'FINTECH_BANKING', 'Banking, Financial Services & Insurance (BFSI)', 2),
(3, 'HEALTHCARE_LIFE_SCI', 'Healthcare & Life Sciences', 3),
(4, 'ECOMMERCE_RETAIL', 'E-Commerce & Digital Marketplaces', 4),
(5, 'TELECOM', 'Telecommunications & Networking', 5),
(6, 'MANUFACTURING', 'Automotive & Industrial Manufacturing', 6)
ON DUPLICATE KEY UPDATE industry_name = VALUES(industry_name);

-- 13. Seed Job Roles
INSERT INTO job_role (id, industry_sector_id, role_code, role_name, display_order) VALUES
(1, 1, 'FULL_STACK_DEV', 'Full Stack Developer', 1),
(2, 1, 'BACKEND_DEV', 'Backend Systems Engineer', 2),
(3, 1, 'FRONTEND_DEV', 'Frontend Web Engineer', 3),
(4, 1, 'DEVOPS_ENGINEER', 'DevOps & Cloud Architect', 4),
(5, 1, 'DATA_SCIENTIST', 'Data Scientist & AI Researcher', 5),
(6, 1, 'DATABASE_ARCHITECT', 'Database Architect & DBA', 6),
(7, 2, 'FINANCIAL_ANALYST', 'Risk & Quantitative Analyst', 7),
(8, 4, 'PRODUCT_LEAD', 'Principal Product Manager', 8)
ON DUPLICATE KEY UPDATE role_name = VALUES(role_name);

-- 14. Seed Roles (Section 3 Actors)
INSERT INTO role_definition (id, role_code, role_name, role_description, is_system_role) VALUES
(1, 'SUPER_ADMIN', 'Super Administrator', 'Complete platform oversight, system configuration, and master control', TRUE),
(2, 'ADMIN', 'System Administrator', 'Operations, support management, and security governance', TRUE),
(3, 'ACCOUNT_ADMIN', 'Employer Account Admin', 'Corporate owner, billing manager, and licence administrator', TRUE),
(4, 'GUEST', 'Anonymous Guest', 'Public search visitor prior to full account onboarding', TRUE),
(5, 'CANDIDATE', 'Candidate Job Seeker', 'Job discovery, profile management, and interview participation', TRUE),
(6, 'EMPLOYER', 'Employer Corporate Poster', 'Requisition creation, questionnaire drafting, and hiring pipeline', TRUE),
(7, 'RECRUITER', 'Corporate Recruiter', 'Sourcing, screening, and interview coordination for mapped employer', TRUE),
(8, 'CONSULTANT', 'Freelance Agency Consultant', 'External sourcing partner working on consultant-open requisitions', TRUE),
(9, 'TPO', 'Training & Placement Officer', 'Campus recruitment officer representing student candidate pools', TRUE)
ON DUPLICATE KEY UPDATE role_name = VALUES(role_name);

-- 15. Seed Subscription Plans (Rule Group 10)
INSERT INTO subscription_plan (id, plan_code, plan_name, billing_interval_code, price_amount, currency_code, included_job_postings_count, included_profile_downloads_count, included_outreach_credits) VALUES
(1, 'PLAN_GROWTH_MONTHLY', 'Growth Recruitment Plan (Monthly)', 'MONTHLY', 14999.00, 'INR', 15, 100, 500),
(2, 'PLAN_ENTERPRISE_ANNUAL', 'Enterprise Scale Plan (Annual)', 'ANNUAL', 149999.00, 'INR', 200, 2000, 10000),
(3, 'PLAN_GIG_PRO_MONTHLY', 'On-Demand Gig Master Plan', 'MONTHLY', 9999.00, 'INR', 50, 300, 1500)
ON DUPLICATE KEY UPDATE price_amount = VALUES(price_amount);

-- 16. Seed Conformed Time Dimension (5 Years: 2024 to 2028)
-- Initial subset seeded for development and query testing
INSERT INTO dim_time (date_actual, calendar_year, calendar_quarter, calendar_month, month_name, calendar_week, day_of_month, day_of_week, day_name, is_weekend, fiscal_quarter)
VALUES 
('2026-10-15', 2026, 4, 10, 'October', 42, 15, 5, 'Thursday', FALSE, 'Q3-FY27'),
('2026-10-16', 2026, 4, 10, 'October', 42, 16, 6, 'Friday', FALSE, 'Q3-FY27'),
('2026-10-17', 2026, 4, 10, 'October', 42, 17, 7, 'Saturday', TRUE, 'Q3-FY27'),
('2026-10-18', 2026, 4, 10, 'October', 42, 18, 1, 'Sunday', TRUE, 'Q3-FY27')
ON DUPLICATE KEY UPDATE calendar_year = VALUES(calendar_year);
