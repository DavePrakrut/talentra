/**
 * Talentra Multi-Portal Client Application Logic
 * Powers the 3 dedicated operational portals:
 *   1. Candidate & Gig Portal
 *   2. Employer & Recruiter ATS Portal
 *   3. Talentra Admin Console
 */

let portalMeta = null;
let currentPortal = 'portal-candidate';
let currentCandidateId = 1;
let currentOrgId = 1;

let candidateJobs = [];
let candidateApplications = [];
let allSchemaTables = [];
let pendingApplyJobId = null;

document.addEventListener('DOMContentLoaded', async () => {
  initTheme();
  await initPortalsMeta();
  loadCurrentPortal();
});

// ============================================================================
// 0. Theme Management
// ============================================================================
function initTheme() {
  const savedTheme = localStorage.getItem('talentra-theme') || 'light';
  applyTheme(savedTheme);
}

function toggleTheme() {
  const currentTheme = document.documentElement.getAttribute('data-theme') || 'light';
  const newTheme = currentTheme === 'light' ? 'dark' : 'light';
  applyTheme(newTheme);
  localStorage.setItem('talentra-theme', newTheme);
}

function applyTheme(theme) {
  document.documentElement.setAttribute('data-theme', theme);
  const sunIcon = document.getElementById('theme-sun-icon');
  const moonIcon = document.getElementById('theme-moon-icon');
  const label = document.getElementById('theme-label');

  if (theme === 'dark') {
    if (sunIcon) sunIcon.style.display = 'block';
    if (moonIcon) moonIcon.style.display = 'none';
    if (label) label.innerText = 'Light Mode';
  } else {
    if (sunIcon) sunIcon.style.display = 'none';
    if (moonIcon) moonIcon.style.display = 'block';
    if (label) label.innerText = 'Dark Mode';
  }
}

// ============================================================================
// 1. Portal Initialization & Persona Management
// ============================================================================
async function initPortalsMeta() {
  try {
    const res = await fetch('/api/portals/meta');
    const json = await res.json();
    if (!json.success) return;
    portalMeta = json.data;

    // Populate Job Role filter & dropdowns
    const candRoleFilter = document.getElementById('cand-job-role-filter');
    const jobRoleSelect = document.getElementById('job-role-select');
    portalMeta.roles.forEach(r => {
      if (candRoleFilter) candRoleFilter.add(new Option(r.role_name, r.id));
      if (jobRoleSelect) jobRoleSelect.add(new Option(r.role_name, r.id));
    });

    // Populate Cities
    const candCityFilter = document.getElementById('cand-job-city-filter');
    const jobCitySelect = document.getElementById('job-city-select');
    portalMeta.cities.forEach(c => {
      if (candCityFilter) candCityFilter.add(new Option(c.city_name, c.id));
      if (jobCitySelect) jobCitySelect.add(new Option(c.city_name, c.id));
    });

    // Populate Employment Types & Work Modes
    const workModeSelect = document.getElementById('job-work-mode-select');
    portalMeta.work_modes.forEach(wm => {
      if (workModeSelect) workModeSelect.add(new Option(wm.display_name, wm.id));
    });

    updatePersonaSelector();
  } catch (err) {
    console.error('Failed to load portal meta:', err);
  }
}

function updatePersonaSelector() {
  if (!portalMeta) return;
  const select = document.getElementById('active-persona-select');
  const label = document.getElementById('persona-label');
  const container = document.getElementById('persona-selector-container');
  select.innerHTML = '';

  if (currentPortal === 'portal-candidate') {
    container.style.display = 'flex';
    label.innerText = 'Candidate:';
    portalMeta.candidates.forEach(c => {
      const opt = new Option(`${c.display_name} (${c.role_name || 'Engineer'}, ${c.city_name || 'India'})`, c.id);
      if (c.id == currentCandidateId) opt.selected = true;
      select.add(opt);
    });
    updateQuickInfo(`Logged in as Candidate #${currentCandidateId}`);
  } else if (currentPortal === 'portal-employer') {
    container.style.display = 'flex';
    label.innerText = 'Employer:';
    portalMeta.organisations.forEach(o => {
      const opt = new Option(`${o.trade_name} (${o.verification_status_code})`, o.id);
      if (o.id == currentOrgId) opt.selected = true;
      select.add(opt);
    });
    updateQuickInfo(`Managing ATS for Org #${currentOrgId}`);
  } else {
    // Admin console
    container.style.display = 'none';
    updateQuickInfo('Super Admin: Northbridge Platform Governance');
  }
}

function updateQuickInfo(text) {
  const el = document.getElementById('portal-quick-info');
  if (el) {
    el.innerHTML = `<span class="badge badge-slate" style="font-size: 12px; padding: 4px 10px;">${text}</span>`;
  }
}

function onPersonaChanged() {
  const select = document.getElementById('active-persona-select');
  if (currentPortal === 'portal-candidate') {
    currentCandidateId = select.value;
  } else if (currentPortal === 'portal-employer') {
    currentOrgId = select.value;
  }
  loadCurrentPortal();
}

function switchPortal(portalId) {
  currentPortal = portalId;

  // Toggle active button in portal bar
  document.querySelectorAll('.portal-switch-btn').forEach(btn => {
    btn.classList.toggle('active', btn.getAttribute('data-portal') === portalId);
  });

  // Toggle active portal container
  document.querySelectorAll('.portal-container').forEach(c => {
    c.classList.toggle('active', c.id === portalId);
  });

  updatePersonaSelector();
  loadCurrentPortal();
}

function loadCurrentPortal() {
  if (currentPortal === 'portal-candidate') {
    loadCandidateJobs();
    loadCandidateApplications();
    loadCandidatePrivacyBlocks();
    loadCandidateProfile();
    loadCandidateGigs();
  } else if (currentPortal === 'portal-employer') {
    loadEmployerOverview();
    loadEmployerJobs();
    loadEmployerSourcing();
    loadEmployerWallet();
  } else if (currentPortal === 'portal-admin') {
    loadKpiData();
    loadAdminOrganisations();
    loadAdminSessions();
    loadAdminAudit();
    loadBenchmarkQueries();
    loadSchema();
  }
}

// ============================================================================
// 2. PORTAL 1: CANDIDATE & GIG ACTIONS
// ============================================================================
function switchCandTab(subtabId) {
  document.querySelectorAll('#portal-candidate .tab-btn').forEach(btn => {
    btn.classList.toggle('active', btn.getAttribute('data-subtab') === subtabId);
  });
  document.querySelectorAll('.cand-subtab').forEach(tab => {
    tab.style.display = tab.id === subtabId ? 'block' : 'none';
  });

  if (subtabId === 'cand-tab-jobs') loadCandidateJobs();
  if (subtabId === 'cand-tab-applications') loadCandidateApplications();
  if (subtabId === 'cand-tab-privacy') loadCandidatePrivacyBlocks();
  if (subtabId === 'cand-tab-profile') loadCandidateProfile();
  if (subtabId === 'cand-tab-gigs') loadCandidateGigs();
}

async function loadCandidateJobs() {
  const container = document.getElementById('cand-jobs-container');
  const search = document.getElementById('cand-job-search')?.value.trim() || '';
  const roleId = document.getElementById('cand-job-role-filter')?.value || '';
  const cityId = document.getElementById('cand-job-city-filter')?.value || '';

  const params = new URLSearchParams();
  params.append('candidate_id', currentCandidateId);
  if (search) params.append('q', search);
  if (roleId) params.append('role_id', roleId);
  if (cityId) params.append('city_id', cityId);

  try {
    const res = await fetch(`/api/candidate/jobs?${params.toString()}`);
    const json = await res.json();
    if (!json.success) return;

    candidateJobs = json.data.jobs;
    document.getElementById('cand-jobs-count-badge').innerText = `${candidateJobs.length} Requisitions Available`;

    if (candidateJobs.length === 0) {
      container.innerHTML = `
        <div style="grid-column: 1 / -1; text-align: center; padding: 2rem; color: var(--text-tertiary);">
          No published requisitions match your criteria, or jobs from blocked employers have been excluded.
        </div>`;
      return;
    }

    container.innerHTML = candidateJobs.map(j => {
      const matchColor = j.match_score >= 80 ? 'badge-emerald' : j.match_score >= 60 ? 'badge-blue' : 'badge-amber';
      const hasApplied = Boolean(j.existing_application_status);
      const applyBtnHtml = hasApplied
        ? `<span class="status-badge status-${j.existing_application_status.toLowerCase()}">Status: ${j.existing_application_status}</span>`
        : `<button class="btn-primary" style="padding: 6px 14px; font-size: 12px;" onclick="openApplyModal(${j.id}, '${escapeHtml(j.job_title)}', '${escapeHtml(j.company_name)}')">Apply Now</button>`;

      return `
        <div class="candidate-card">
          <div style="display: flex; justify-content: space-between; align-items: flex-start; margin-bottom: 0.5rem;">
            <div>
              <div style="font-size: 15px; font-weight: 600; color: var(--text-primary);">${escapeHtml(j.job_title)}</div>
              <div style="font-size: 13px; color: var(--text-secondary); margin-top: 2px;">
                <strong>${escapeHtml(j.company_name)}</strong> · ${escapeHtml(j.city_name || 'Remote')}
              </div>
            </div>
            <span class="badge ${matchColor}">${j.match_score}% Match</span>
          </div>

          <div style="font-size: 12px; color: var(--text-tertiary); margin-bottom: 0.75rem; line-height: 1.4;">
            ${escapeHtml(j.job_description.substring(0, 140))}...
          </div>

          <div style="display: flex; flex-wrap: wrap; gap: 4px; margin-bottom: 0.75rem;">
            ${j.required_skills_list ? j.required_skills_list.split(',').map(s => `<span class="skill-tag">${escapeHtml(s.trim())}</span>`).join('') : ''}
          </div>

          <div style="display: flex; justify-content: space-between; align-items: center; border-top: 1px solid var(--border-divider); padding-top: 0.75rem;">
            <div>
              <div style="font-size: 11px; color: var(--text-muted); text-transform: uppercase;">Salary Band</div>
              <div style="font-size: 13px; font-weight: 600; color: var(--text-primary);">
                ₹${(j.minimum_salary / 100000).toFixed(1)}L - ₹${(j.maximum_salary / 100000).toFixed(1)}L
              </div>
            </div>
            ${applyBtnHtml}
          </div>
        </div>`;
    }).join('');
  } catch (err) {
    console.error('Failed to load candidate jobs:', err);
  }
}

function filterCandidateJobs() {
  loadCandidateJobs();
}

function openApplyModal(jobId, jobTitle, companyName) {
  pendingApplyJobId = jobId;
  document.getElementById('apply-modal-title').innerText = `Apply for ${jobTitle}`;
  document.getElementById('apply-modal-desc').innerText = `Submit your application directly to ${companyName}. Your verified profile and resume will be linked.`;
  openModal('modal-apply-job');
}

async function submitJobApplication() {
  if (!pendingApplyJobId) return;
  const btn = document.getElementById('btn-confirm-apply');
  btn.innerText = 'Submitting ...';
  btn.disabled = true;

  try {
    const res = await fetch('/api/candidate/apply', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        candidate_id: currentCandidateId,
        job_id: pendingApplyJobId
      })
    });
    const json = await res.json();
    btn.innerText = 'Submit Application';
    btn.disabled = false;
    closeModal('modal-apply-job');

    if (json.success) {
      alert(`🎉 ${json.message} (Match score: ${json.data.match_score}%)`);
      loadCandidateJobs();
      loadCandidateApplications();
    } else {
      alert(`⚠️ ${json.error}`);
    }
  } catch (err) {
    btn.innerText = 'Submit Application';
    btn.disabled = false;
    alert(`Error: ${err.message}`);
  }
}

async function loadCandidateApplications() {
  try {
    const res = await fetch(`/api/candidate/my_applications?candidate_id=${currentCandidateId}`);
    const json = await res.json();
    if (!json.success) return;

    candidateApplications = json.data.applications;
    document.getElementById('cand-app-count-badge').innerText = candidateApplications.length;

    const tbody = document.getElementById('cand-applications-tbody');
    if (candidateApplications.length === 0) {
      tbody.innerHTML = `<tr><td colspan="8" style="text-align: center; color: var(--text-tertiary);">You have not applied to any requisitions yet. Browse open jobs and apply!</td></tr>`;
      return;
    }

    tbody.innerHTML = candidateApplications.map(a => {
      const stageLower = a.application_status_code.toLowerCase();
      const dateFormatted = a.applied_at ? a.applied_at.substring(0, 10) : '-';
      return `
        <tr>
          <td><strong style="color: var(--text-primary);">${escapeHtml(a.job_title)}</strong></td>
          <td>${escapeHtml(a.company_name)}</td>
          <td>${escapeHtml(a.city_name || 'India')}</td>
          <td>₹${(a.minimum_salary / 100000).toFixed(1)}L - ₹${(a.maximum_salary / 100000).toFixed(1)}L</td>
          <td><span class="badge badge-blue">${a.match_score_percentage}%</span></td>
          <td><span class="status-badge status-${stageLower}">${a.application_status_code}</span></td>
          <td>${dateFormatted}</td>
          <td style="font-size: 12px; color: var(--text-tertiary);">${escapeHtml(a.latest_status_note || 'Stage updated')}</td>
        </tr>`;
    }).join('');
  } catch (err) {
    console.error('Failed to load candidate applications:', err);
  }
}

async function loadCandidatePrivacyBlocks() {
  try {
    const res = await fetch(`/api/candidate/privacy_blocks?candidate_id=${currentCandidateId}`);
    const json = await res.json();
    if (!json.success) return;

    const blocks = json.data.blocks;
    document.getElementById('active-blocks-count').innerText = `${blocks.length} Active Block Rules`;

    const activeBlocksContainer = document.getElementById('active-blocks-container');
    if (blocks.length === 0) {
      activeBlocksContainer.innerHTML = `<div style="font-size: 13px; color: var(--text-tertiary); padding: 0.5rem;">No active block rules configured. All verified employers can discover your profile.</div>`;
    } else {
      activeBlocksContainer.innerHTML = blocks.map(b => `
        <div style="display: flex; justify-content: space-between; align-items: center; background-color: var(--bg-subtle); padding: 8px 12px; border-radius: var(--radius-xs); border: 1px solid var(--border-color);">
          <div>
            <strong style="color: var(--text-primary);">${escapeHtml(b.organisation_name || 'Blocked Entity')}</strong>
            <span style="font-size: 12px; color: var(--text-tertiary); margin-left: 8px;">"${escapeHtml(b.block_reason || 'Confidential')}"</span>
          </div>
          <button class="btn-secondary" style="padding: 3px 8px; font-size: 11px;" onclick="unblockEmployer(${b.blocked_target_id})">Unblock</button>
        </div>
      `).join('');
    }

    // Populate Employers table for blocking
    const blockedOrgIds = new Set(blocks.map(b => b.blocked_target_id));
    const tbody = document.getElementById('privacy-employers-tbody');
    tbody.innerHTML = portalMeta.organisations.map(o => {
      const isBlocked = blockedOrgIds.has(o.id);
      const btn = isBlocked
        ? `<button class="btn-secondary" style="padding: 4px 10px; font-size: 12px;" onclick="unblockEmployer(${o.id})">Unblock Employer</button>`
        : `<button class="btn-danger" style="padding: 4px 10px; font-size: 12px;" onclick="blockEmployer(${o.id}, '${escapeHtml(o.trade_name)}')">Block Employer</button>`;

      return `
        <tr>
          <td><strong style="color: var(--text-primary);">${escapeHtml(o.trade_name)}</strong></td>
          <td>${escapeHtml(o.city_name || 'India')}</td>
          <td><span class="badge ${o.verification_status_code === 'VERIFIED' ? 'badge-emerald' : 'badge-slate'}">${o.verification_status_code}</span></td>
          <td>${btn}</td>
        </tr>`;
    }).join('');
  } catch (err) {
    console.error('Failed to load candidate privacy blocks:', err);
  }
}

async function blockEmployer(orgId, orgName) {
  const reason = prompt(`Enter reason for blocking ${orgName} (e.g. Current employer privacy protection):`, 'Current employer privacy protection');
  if (reason === null) return;

  try {
    const res = await fetch('/api/candidate/block_entity', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        candidate_id: currentCandidateId,
        organisation_id: orgId,
        reason: reason
      })
    });
    const json = await res.json();
    if (json.success) {
      alert(`🛡️ ${json.message}`);
      loadCandidatePrivacyBlocks();
      loadCandidateJobs();
    } else {
      alert(`⚠️ ${json.error}`);
    }
  } catch (err) {
    alert(`Error: ${err.message}`);
  }
}

async function unblockEmployer(orgId) {
  try {
    const res = await fetch('/api/candidate/unblock_entity', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        candidate_id: currentCandidateId,
        organisation_id: orgId
      })
    });
    const json = await res.json();
    if (json.success) {
      alert(`✅ ${json.message}`);
      loadCandidatePrivacyBlocks();
      loadCandidateJobs();
    } else {
      alert(`⚠️ ${json.error}`);
    }
  } catch (err) {
    alert(`Error: ${err.message}`);
  }
}

async function loadCandidateProfile() {
  try {
    const res = await fetch(`/api/candidate/profile?candidate_id=${currentCandidateId}`);
    const json = await res.json();
    if (!json.success) return;

    const { profile, skills, education, resumes } = json.data;

    document.getElementById('cand-profile-summary-box').innerHTML = `
      <div style="display: flex; align-items: center; gap: 12px; margin-bottom: 1rem;">
        <div class="candidate-avatar">${getInitials(profile.display_name)}</div>
        <div>
          <div style="font-size: 16px; font-weight: 600; color: var(--text-primary);">${escapeHtml(profile.display_name)}</div>
          <div style="font-size: 13px; color: var(--text-secondary);">${escapeHtml(profile.role_name || 'Software Engineer')} · ${escapeHtml(profile.city_name || 'India')}</div>
        </div>
      </div>
      <div class="meta-row"><span class="meta-label">Email:</span> <span class="meta-val">${escapeHtml(profile.email_address)}</span></div>
      <div class="meta-row"><span class="meta-label">Experience:</span> <span class="meta-val">${profile.experience_years} Years (${profile.total_experience_months} months)</span></div>
      <div class="meta-row"><span class="meta-label">Notice Period:</span> <span class="meta-val">${profile.notice_period_days} Days</span></div>
      <div class="meta-row"><span class="meta-label">Expected Salary:</span> <span class="meta-val">₹${Number(profile.expected_salary || 0).toLocaleString('en-IN')} ${profile.salary_currency_code}</span></div>
      <div class="meta-row"><span class="meta-label">Profile Score:</span> <span class="meta-val"><strong style="color: var(--success-text);">${profile.profile_completion_percentage}%</strong></span></div>
    `;

    document.getElementById('cand-skills-badges').innerHTML = skills.map(s => `
      <span class="skill-tag ${s.is_verified_by_test ? 'skill-verified' : ''}">
        ${escapeHtml(s.skill_name)} (${s.proficiency_level_code})
        ${s.is_verified_by_test ? ' ✓ Test Verified' : ''}
      </span>
    `).join('');

    document.getElementById('cand-resumes-list').innerHTML = resumes.map(r => `
      <div style="display: flex; justify-content: space-between; align-items: center; padding: 6px 0; border-bottom: 1px solid var(--border-divider);">
        <span style="font-size: 13px; color: var(--text-primary);">${escapeHtml(r.resume_title)} (${escapeHtml(r.file_mime_type)})</span>
        <span class="badge ${r.is_primary_resume ? 'badge-emerald' : 'badge-slate'}">${r.is_primary_resume ? 'Primary Active' : 'Archive'}</span>
      </div>
    `).join('');
  } catch (err) {
    console.error('Failed to load candidate profile:', err);
  }
}

async function loadCandidateGigs() {
  const container = document.getElementById('cand-gigs-container');
  try {
    const res = await fetch('/api/gigs');
    const json = await res.json();
    if (!json.success) return;

    container.innerHTML = json.data.gig_requests.map(g => `
      <div class="candidate-card">
        <div style="display: flex; justify-content: space-between; margin-bottom: 0.5rem;">
          <div style="font-size: 15px; font-weight: 600; color: var(--text-primary);">${escapeHtml(g.gig_title)}</div>
          <span class="badge badge-emerald">${g.pricing_model_code}</span>
        </div>
        <div style="font-size: 13px; color: var(--text-secondary); margin-bottom: 0.5rem;">
          ${escapeHtml(g.company_name)} · ${escapeHtml(g.city_name)}
        </div>
        <div style="font-size: 12px; color: var(--text-tertiary); margin-bottom: 0.75rem;">
          Window: ${g.window_start_time.substring(0, 10)} to ${g.window_end_time.substring(0, 10)}
        </div>
        <div style="display: flex; justify-content: space-between; align-items: center; border-top: 1px solid var(--border-divider); padding-top: 0.75rem;">
          <div style="font-size: 14px; font-weight: 600; color: var(--text-primary);">₹${Number(g.budget_amount).toLocaleString('en-IN')}</div>
          <button class="btn-primary" style="padding: 4px 12px; font-size: 12px;" onclick="submitGigBid(${g.id}, '${escapeHtml(g.gig_title)}')">Submit Proposal</button>
        </div>
      </div>
    `).join('');
  } catch (err) {
    console.error('Failed to load gigs:', err);
  }
}

async function submitGigBid(gigId, gigTitle) {
  const rate = prompt(`Enter your proposed quote for "${gigTitle}":`, '45000');
  if (!rate) return;

  try {
    const res = await fetch('/api/candidate/gig_bid', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        candidate_id: currentCandidateId,
        gig_request_id: gigId,
        bid_amount: parseFloat(rate)
      })
    });
    const json = await res.json();
    if (json.success) {
      alert(`⚡ ${json.message}`);
    } else {
      alert(`⚠️ ${json.error}`);
    }
  } catch (err) {
    alert(`Error: ${err.message}`);
  }
}

// ============================================================================
// 3. PORTAL 2: EMPLOYER & RECRUITER ATS ACTIONS
// ============================================================================
function switchEmpTab(subtabId) {
  document.querySelectorAll('#portal-employer .tab-btn').forEach(btn => {
    btn.classList.toggle('active', btn.getAttribute('data-subtab') === subtabId);
  });
  document.querySelectorAll('.emp-subtab').forEach(tab => {
    tab.style.display = tab.id === subtabId ? 'block' : 'none';
  });

  if (subtabId === 'emp-tab-pipeline') loadEmployerJobs();
  if (subtabId === 'emp-tab-sourcing') loadEmployerSourcing();
  if (subtabId === 'emp-tab-wallet') loadEmployerWallet();
}

async function loadEmployerOverview() {
  try {
    const res = await fetch(`/api/employer/overview?org_id=${currentOrgId}`);
    const json = await res.json();
    if (!json.success) return;

    const { organisation, licence } = json.data;
    document.getElementById('emp-wallet-display-val').innerText = '₹ ' + Number(organisation.current_credit_balance || 0).toLocaleString('en-IN', { maximumFractionDigits: 0 });
    document.getElementById('emp-sourcing-wallet-balance').innerText = Number(organisation.current_credit_balance || 0).toLocaleString();

    if (licence) {
      document.getElementById('emp-licence-tier-badge').innerText = licence.licence_tier_code;
      document.getElementById('emp-licence-seats-val').innerText = `${licence.max_users} Seats / ${licence.max_devices_per_user} Devices per User`;
    }
  } catch (err) {
    console.error('Failed to load employer overview:', err);
  }
}

let selectedEmployerJobId = null;

async function loadEmployerJobs() {
  try {
    const res = await fetch(`/api/employer/jobs?org_id=${currentOrgId}`);
    const json = await res.json();
    if (!json.success) return;

    const jobs = json.data.jobs;
    const listEl = document.getElementById('emp-jobs-list');

    if (jobs.length === 0) {
      listEl.innerHTML = `<div style="font-size: 13px; color: var(--text-tertiary); padding: 1rem;">No requisitions posted yet. Click "Create Requisition" above to publish one!</div>`;
      document.getElementById('emp-applicants-tbody').innerHTML = `<tr><td colspan="5" style="text-align: center; color: var(--text-tertiary);">No requisitions available.</td></tr>`;
      return;
    }

    // Determine currently selected job
    if (!selectedEmployerJobId || !jobs.some(j => j.id == selectedEmployerJobId)) {
      selectedEmployerJobId = jobs[0].id;
    }

    listEl.innerHTML = jobs.map((j) => {
      const isSelected = j.id == selectedEmployerJobId;
      return `
        <div class="pipeline-job-card ${isSelected ? 'selected' : ''}" data-job-id="${j.id}" onclick="selectEmployerJob(${j.id}, this)">
          <div style="display: flex; justify-content: space-between; align-items: flex-start; margin-bottom: 4px;">
            <div style="font-size: 13px; font-weight: 600; color: var(--text-primary);">${escapeHtml(j.job_title)}</div>
            <span class="badge ${j.publish_state_code === 'PUBLISHED' ? 'badge-emerald' : 'badge-slate'}">${j.publish_state_code}</span>
          </div>
          <div style="font-size: 12px; color: var(--text-tertiary); margin-bottom: 6px;">
            ${escapeHtml(j.city_name || 'India')} · ${j.positions_filled_count}/${j.positions_count} Filled
          </div>
          <div style="display: flex; gap: 4px; font-size: 11px;">
            <span class="badge badge-blue">${j.stage_applied || 0} Applied</span>
            <span class="badge badge-amber">${j.stage_shortlisted || 0} Shortlisted</span>
            <span class="badge badge-emerald">${j.stage_joined || 0} Hired</span>
          </div>
        </div>`;
    }).join('');

    // Fetch and display applicants for the selected job
    selectEmployerJob(selectedEmployerJobId);
  } catch (err) {
    console.error('Failed to load employer jobs:', err);
  }
}

async function selectEmployerJob(jobId, cardEl = null) {
  selectedEmployerJobId = jobId;

  // Update selected class on left sidebar cards
  document.querySelectorAll('.pipeline-job-card').forEach(c => {
    c.classList.toggle('selected', c.getAttribute('data-job-id') == jobId);
  });

  try {
    const res = await fetch(`/api/employer/job_applicants?job_id=${jobId}`);
    const json = await res.json();

    if (!json.success) {
      console.error('Failed to load applicants:', json.error);
      document.getElementById('emp-applicants-tbody').innerHTML = `
        <tr><td colspan="5" style="text-align: center; color: var(--danger-text);">Error loading applicants: ${escapeHtml(json.error)}</td></tr>`;
      return;
    }

    const applicants = json.data.applicants;
    document.getElementById('emp-job-applicants-count').innerText = `${applicants.length} Applicants`;
    
    // Find job title from the selected card
    const activeCard = document.querySelector(`.pipeline-job-card[data-job-id="${jobId}"]`);
    const jobTitle = activeCard ? activeCard.querySelector('div').innerText : `Requisition #${jobId}`;
    document.getElementById('emp-selected-job-title').innerText = `Applicants for: ${jobTitle}`;

    const tbody = document.getElementById('emp-applicants-tbody');
    if (applicants.length === 0) {
      tbody.innerHTML = `<tr><td colspan="5" style="text-align: center; color: var(--text-tertiary); padding: 2rem;">No candidates have applied to this requisition yet.</td></tr>`;
      return;
    }

    tbody.innerHTML = applicants.map(a => {
      const stageLower = a.application_status_code.toLowerCase();
      return `
        <tr>
          <td>
            <strong style="color: var(--text-primary); font-size: 13.5px;">${escapeHtml(a.display_name)}</strong>
            <div style="font-size: 11px; color: var(--text-tertiary); margin-top: 1px;">${escapeHtml(a.email_address)} · ${escapeHtml(a.phone || '')}</div>
            <div style="font-size: 11px; color: var(--text-muted); margin-top: 2px;">Skills: ${escapeHtml(a.candidate_skills || 'General Engineering')}</div>
          </td>
          <td><strong>${a.experience_years}</strong> yrs</td>
          <td><span class="badge ${a.match_score_percentage >= 70 ? 'badge-emerald' : 'badge-blue'}">${a.match_score_percentage}%</span></td>
          <td><span class="status-badge status-${stageLower}">${a.application_status_code}</span></td>
          <td>
            <div class="stage-btn-group">
              <button class="btn-shortlist" onclick="advanceApplicantStage(${a.application_id}, 'SHORTLISTED')">Shortlist</button>
              <button class="btn-interview" onclick="advanceApplicantStage(${a.application_id}, 'INTERVIEWED')">Interview</button>
              <button class="btn-offer" onclick="advanceApplicantStage(${a.application_id}, 'OFFERED')">Offer</button>
              <button class="btn-hire" onclick="advanceApplicantStage(${a.application_id}, 'JOINED')">Hire / Joined</button>
              <button class="btn-reject" onclick="advanceApplicantStage(${a.application_id}, 'REJECTED')">Reject</button>
            </div>
          </td>
        </tr>`;
    }).join('');
  } catch (err) {
    console.error('Failed to load job applicants:', err);
  }
}

async function advanceApplicantStage(appId, newStage) {
  try {
    const res = await fetch('/api/employer/advance_stage', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        application_id: appId,
        new_stage: newStage,
        actor_user_id: 1,
        notes: `Candidate progressed to ${newStage} by hiring manager`
      })
    });
    const json = await res.json();
    if (json.success) {
      // Reload jobs to refresh counts and refresh applicants table
      loadEmployerJobs();
    } else {
      alert(`⚠️ ${json.error}`);
    }
  } catch (err) {
    alert(`Error: ${err.message}`);
  }
}

async function handleCreateJobSubmit(e) {
  e.preventDefault();
  const title = document.getElementById('job-title-input').value.trim();
  const roleId = document.getElementById('job-role-select').value;
  const cityId = document.getElementById('job-city-select').value;
  const positions = document.getElementById('job-positions-input').value;
  const workModeId = document.getElementById('job-work-mode-select').value;
  const minSal = document.getElementById('job-min-salary-input').value;
  const maxSal = document.getElementById('job-max-salary-input').value;
  const desc = document.getElementById('job-desc-input').value;
  const isConsultantOpen = document.getElementById('job-consultant-open').checked;

  try {
    const res = await fetch('/api/employer/create_job', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        organisation_id: currentOrgId,
        job_title: title,
        job_role_id: roleId,
        city_id: cityId,
        employment_type_id: 1,
        work_mode_id: workModeId,
        positions_count: positions,
        minimum_salary: minSal,
        maximum_salary: maxSal,
        description: desc,
        is_open_to_consultants: isConsultantOpen,
        skill_ids: [1, 2, 3]
      })
    });
    const json = await res.json();
    if (json.success) {
      alert(`🎉 ${json.message}`);
      switchEmpTab('emp-tab-pipeline');
    } else {
      alert(`⚠️ ${json.error}`);
    }
  } catch (err) {
    alert(`Error: ${err.message}`);
  }
}

async function loadEmployerSourcing() {
  const container = document.getElementById('emp-candidate-sourcing-container');
  try {
    const res = await fetch(`/api/candidates?blocked_org_id=${currentOrgId}&apply_privacy_blocking=true`);
    const json = await res.json();
    if (!json.success) return;

    const candidates = json.data.candidates;
    container.innerHTML = candidates.map(c => `
      <div class="candidate-card">
        <div style="display: flex; justify-content: space-between; align-items: flex-start; margin-bottom: 0.5rem;">
          <div style="display: flex; gap: 10px; align-items: center;">
            <div class="candidate-avatar">${getInitials(c.display_name)}</div>
            <div>
              <div style="font-size: 14px; font-weight: 600; color: var(--text-primary);">${escapeHtml(c.display_name)}</div>
              <div style="font-size: 12px; color: var(--text-tertiary);">${escapeHtml(c.role_name || 'Engineer')} · ${escapeHtml(c.city_name || 'India')}</div>
            </div>
          </div>
          <span class="badge badge-emerald">${c.experience_years} yrs</span>
        </div>

        <div style="font-size: 12px; color: var(--text-secondary); margin-bottom: 0.5rem;">
          Notice: <strong>${c.notice_period_days} Days</strong> · Skills: ${escapeHtml(c.top_skills || 'Full stack')}
        </div>

        <div style="display: flex; justify-content: space-between; align-items: center; border-top: 1px solid var(--border-divider); padding-top: 0.75rem;">
          <div style="font-size: 12px; color: var(--text-tertiary);">Score: ${c.profile_completion_percentage}%</div>
          <button class="btn-primary" style="padding: 4px 10px; font-size: 12px;" onclick="downloadResume(${c.id}, '${escapeHtml(c.display_name)}')">
            Download CV (10 Credits)
          </button>
        </div>
      </div>
    `).join('');
  } catch (err) {
    console.error('Failed to load sourcing candidates:', err);
  }
}

async function downloadResume(candidateId, candidateName) {
  if (!confirm(`Deduct 10 credits from your wallet to download ${candidateName}'s verified resume?`)) return;

  try {
    const res = await fetch('/api/employer/download_resume', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        organisation_id: currentOrgId,
        candidate_id: candidateId,
        actor_user_id: 1
      })
    });
    const json = await res.json();
    if (json.success) {
      alert(`✅ ${json.message}`);
      loadEmployerOverview();
    } else {
      alert(`⚠️ ${json.error}`);
    }
  } catch (err) {
    alert(`Error: ${err.message}`);
  }
}

async function handleCreateGigSubmit(e) {
  e.preventDefault();
  const title = document.getElementById('gig-title-input').value.trim();
  const pricing = document.getElementById('gig-pricing-select').value;
  const budget = document.getElementById('gig-budget-input').value;
  const start = document.getElementById('gig-start-input').value + ' 09:00:00';
  const end = document.getElementById('gig-end-input').value + ' 18:00:00';
  const desc = document.getElementById('gig-desc-input').value;

  try {
    const res = await fetch('/api/employer/create_gig', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        organisation_id: currentOrgId,
        gig_title: title,
        pricing_model: pricing,
        budget: budget,
        start_date: start,
        end_date: end,
        description: desc
      })
    });
    const json = await res.json();
    if (json.success) {
      alert(`⚡ ${json.message}`);
      e.target.reset();
    } else {
      alert(`⚠️ ${json.error}`);
    }
  } catch (err) {
    alert(`Error: ${err.message}`);
  }
}

async function loadEmployerWallet() {
  try {
    const res = await fetch(`/api/employer/wallet?org_id=${currentOrgId}`);
    const json = await res.json();
    if (!json.success) return;

    const { wallet, transactions } = json.data;
    document.getElementById('emp-wallet-display-val').innerText = '₹ ' + Number(wallet.current_credit_balance || 0).toLocaleString('en-IN', { maximumFractionDigits: 0 });

    const tbody = document.getElementById('emp-wallet-transactions-tbody');
    if (transactions.length === 0) {
      tbody.innerHTML = `<tr><td colspan="6" style="text-align: center; color: var(--text-tertiary);">No ledger transactions recorded yet.</td></tr>`;
      return;
    }

    tbody.innerHTML = transactions.map(t => `
      <tr>
        <td>#${t.id}</td>
        <td><span class="badge ${t.transaction_amount >= 0 ? 'badge-emerald' : 'badge-slate'}">${t.transaction_type_code}</span></td>
        <td style="font-weight: 600; color: ${t.transaction_amount >= 0 ? 'var(--success-text)' : 'var(--danger-text)'};">
          ${t.transaction_amount >= 0 ? '+' : ''}${Number(t.transaction_amount).toLocaleString()}
        </td>
        <td>₹${Number(t.balance_after_transaction).toLocaleString()}</td>
        <td style="font-size: 12px; color: var(--text-secondary);">${escapeHtml(t.transaction_description)}</td>
        <td style="font-size: 11px; color: var(--text-tertiary);">${t.transaction_timestamp.substring(0, 19)}</td>
      </tr>
    `).join('');
  } catch (err) {
    console.error('Failed to load employer wallet:', err);
  }
}

function openRechargeModal() {
  openModal('modal-recharge-wallet');
}

async function submitWalletRecharge() {
  const credits = document.getElementById('recharge-package-select').value;
  try {
    const res = await fetch('/api/employer/recharge_wallet', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        organisation_id: currentOrgId,
        credits: parseInt(credits),
        amount_inr: parseInt(credits) * 10
      })
    });
    const json = await res.json();
    closeModal('modal-recharge-wallet');

    if (json.success) {
      alert(`💳 ${json.message}`);
      loadEmployerOverview();
      loadEmployerWallet();
    } else {
      alert(`⚠️ ${json.error}`);
    }
  } catch (err) {
    alert(`Error: ${err.message}`);
  }
}

// ============================================================================
// 4. PORTAL 3: TALENTRA ADMIN CONSOLE
// ============================================================================
function switchAdminTab(subtabId) {
  document.querySelectorAll('#portal-admin .tab-btn').forEach(btn => {
    btn.classList.toggle('active', btn.getAttribute('data-subtab') === subtabId);
  });
  document.querySelectorAll('.admin-subtab').forEach(tab => {
    tab.style.display = tab.id === subtabId ? 'block' : 'none';
  });

  if (subtabId === 'admin-tab-overview') loadKpiData();
  if (subtabId === 'admin-tab-verification') loadAdminOrganisations();
  if (subtabId === 'admin-tab-sessions') loadAdminSessions();
  if (subtabId === 'admin-tab-audit') loadAdminAudit();
  if (subtabId === 'admin-tab-benchmark') loadBenchmarkQueries();
  if (subtabId === 'admin-tab-schema') loadSchema();
}

async function loadKpiData() {
  try {
    const res = await fetch('/api/kpi');
    const json = await res.json();
    if (!json.success) return;

    const d = json.data;
    document.getElementById('kpi-candidates').innerText = Number(d.total_candidates).toLocaleString();
    document.getElementById('kpi-orgs').innerText = Number(d.total_organisations).toLocaleString();
    document.getElementById('kpi-jobs').innerText = Number(d.total_jobs).toLocaleString();
    document.getElementById('kpi-applications').innerText = Number(d.pipeline.total_applications || 0).toLocaleString();
    document.getElementById('kpi-wallet').innerText = '₹ ' + Number(d.financial.total_wallet_balance || 0).toLocaleString('en-IN', { maximumFractionDigits: 0 });
    document.getElementById('kpi-gigs').innerText = Number(d.gig_stats.total_gig_requests || 0).toLocaleString();

    document.getElementById('stage-applied').innerText = Number(d.pipeline.applied || 0).toLocaleString();
    document.getElementById('stage-shortlisted').innerText = Number(d.pipeline.shortlisted || 0).toLocaleString();
    document.getElementById('stage-interviewed').innerText = Number(d.pipeline.interviewed || 0).toLocaleString();
    document.getElementById('stage-offered').innerText = Number(d.pipeline.offered || 0).toLocaleString();
    document.getElementById('stage-joined').innerText = Number(d.pipeline.joined || 0).toLocaleString();
    document.getElementById('stage-rejected').innerText = Number(d.pipeline.rejected || 0).toLocaleString();
  } catch (err) {
    console.error('Failed to load KPI metrics:', err);
  }
}

async function loadAdminOrganisations() {
  try {
    const res = await fetch('/api/admin/organisations');
    const json = await res.json();
    if (!json.success) return;

    const tbody = document.getElementById('admin-orgs-tbody');
    tbody.innerHTML = json.data.organisations.map(o => {
      const isVerified = o.verification_status_code === 'VERIFIED';
      const actionBtn = isVerified
        ? `<span class="badge badge-emerald">Verified</span>`
        : `<button class="btn-primary" style="padding: 3px 8px; font-size: 11px;" onclick="verifyOrganisation(${o.id})">Verify</button>`;

      return `
        <tr>
          <td><strong style="color: var(--text-primary);">${escapeHtml(o.trade_name)}</strong></td>
          <td>${escapeHtml(o.legal_name)}</td>
          <td><code>${escapeHtml(o.identifier_value_masked || o.tax_registration_identifier || 'CIN-7849-XXXX')}</code></td>
          <td><span class="badge ${isVerified ? 'badge-emerald' : 'badge-slate'}">${o.verification_status_code}</span></td>
          <td>₹${Number(o.current_credit_balance || 0).toLocaleString()}</td>
          <td>${actionBtn}</td>
        </tr>`;
    }).join('');
  } catch (err) {
    console.error('Failed to load admin organisations:', err);
  }
}

async function verifyOrganisation(orgId) {
  try {
    const res = await fetch('/api/admin/verify_organisation', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ organisation_id: orgId })
    });
    const json = await res.json();
    if (json.success) {
      alert(`🏛️ ${json.message}`);
      loadAdminOrganisations();
    } else {
      alert(`⚠️ ${json.error}`);
    }
  } catch (err) {
    alert(`Error: ${err.message}`);
  }
}

async function loadAdminSessions() {
  try {
    const res = await fetch('/api/admin/sessions');
    const json = await res.json();
    if (!json.success) return;

    const tbody = document.getElementById('admin-sessions-tbody');
    tbody.innerHTML = json.data.sessions.map(s => `
      <tr>
        <td>#${s.session_id}</td>
        <td>${escapeHtml(s.email_address)}</td>
        <td><strong>${escapeHtml(s.device_name)}</strong></td>
        <td><span class="badge badge-slate">${s.device_type_code}</span></td>
        <td>${escapeHtml(s.operating_system)} / ${escapeHtml(s.browser_name)}</td>
        <td><code>${escapeHtml(s.ip_address)}</code></td>
        <td style="font-size: 11px; color: var(--text-tertiary);">${s.last_activity_time.substring(0, 19)}</td>
        <td>
          <button class="btn-danger" style="padding: 2px 6px; font-size: 11px;" onclick="revokeSession(${s.session_id})">Revoke</button>
        </td>
      </tr>
    `).join('');
  } catch (err) {
    console.error('Failed to load admin sessions:', err);
  }
}

async function revokeSession(sessionId) {
  if (!confirm(`Terminate active session #${sessionId}?`)) return;

  try {
    const res = await fetch('/api/admin/revoke_session', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ session_id: sessionId })
    });
    const json = await res.json();
    if (json.success) {
      alert(`🔐 ${json.message}`);
      loadAdminSessions();
    } else {
      alert(`⚠️ ${json.error}`);
    }
  } catch (err) {
    alert(`Error: ${err.message}`);
  }
}

async function testSessionLimit() {
  try {
    const res = await fetch('/api/admin/test_session_limit', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ user_id: 1 })
    });
    const json = await res.json();
    if (json.success) {
      const d = json.data;
      alert(`🚀 Concurrency Test Result: Status = "${d.status_code}", Session ID = ${d.session_id || 'Denied'}.\nEnforced by: ${d.enforced_by}`);
      loadAdminSessions();
    } else {
      alert(`⚠️ ${json.error}`);
    }
  } catch (err) {
    alert(`Error: ${err.message}`);
  }
}

async function loadAdminAudit() {
  try {
    const res = await fetch('/api/audit');
    const json = await res.json();
    if (!json.success) return;

    const tbody = document.getElementById('admin-audit-tbody');
    tbody.innerHTML = json.data.audit_events.map(ev => `
      <tr>
        <td>#${ev.id}</td>
        <td><span class="badge badge-blue">${ev.action_type}</span></td>
        <td>${escapeHtml(ev.target_entity_name)}</td>
        <td>#${ev.target_entity_id}</td>
        <td>User #${ev.actor_user_id || 'System'}</td>
        <td><code>${escapeHtml(ev.ip_address)}</code></td>
        <td style="font-size: 11px; color: var(--text-tertiary);">${ev.action_timestamp.substring(0, 19)}</td>
      </tr>
    `).join('');
  } catch (err) {
    console.error('Failed to load admin audit:', err);
  }
}

async function loadBenchmarkQueries() {
  const container = document.getElementById('queries-list-container');
  try {
    const res = await fetch('/api/benchmark/queries');
    const json = await res.json();
    if (!json.success) return;

    container.innerHTML = json.data.map(q => `
      <div class="query-card" id="query-card-${q.id}">
        <div class="query-card-header">
          <div style="display: flex; align-items: center; gap: 8px;">
            <span class="badge badge-slate">Q${q.id}</span>
            <span class="query-title">${escapeHtml(q.title)}</span>
          </div>
          <button class="btn-primary" style="padding: 4px 12px; font-size: 12px;" onclick="runBenchmarkQuery(${q.id})">
            Run Live Query
          </button>
        </div>
        <div class="query-sql-box">${escapeHtml(q.sql)}</div>
        <div class="query-results-area" id="query-results-${q.id}" style="display: none;"></div>
      </div>
    `).join('');
  } catch (err) {
    console.error('Failed to load benchmark queries:', err);
  }
}

async function runBenchmarkQuery(queryId) {
  const resultsArea = document.getElementById(`query-results-${queryId}`);
  resultsArea.style.display = 'block';
  resultsArea.innerHTML = `<div style="color: var(--text-tertiary); font-size: 12px;">Executing on MySQL 8.0 InnoDB ...</div>`;

  try {
    const res = await fetch('/api/benchmark/run', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ query_id: queryId })
    });
    const json = await res.json();
    if (!json.success) {
      resultsArea.innerHTML = `<div style="color: var(--danger-text); font-size: 12px;">Query failed: ${json.error}</div>`;
      return;
    }

    const d = json.data;
    resultsArea.innerHTML = `
      <div style="display: flex; gap: 12px; margin-bottom: 8px; font-size: 12px;">
        <span class="badge badge-emerald">Latency: ${d.latency_ms} ms</span>
        <span class="badge badge-blue">${d.row_count} Rows Returned</span>
      </div>
      <div class="table-responsive" style="max-height: 200px; font-size: 11px;">
        <table class="data-table">
          <thead><tr>${d.columns.map(c => `<th>${escapeHtml(c)}</th>`).join('')}</tr></thead>
          <tbody>${d.rows.slice(0, 5).map(r => `<tr>${r.map(val => `<td>${escapeHtml(String(val !== null ? val : 'NULL'))}</td>`).join('')}</tr>`).join('')}</tbody>
        </table>
      </div>
    `;
  } catch (err) {
    resultsArea.innerHTML = `<div style="color: var(--danger-text); font-size: 12px;">Execution error: ${err.message}</div>`;
  }
}

async function loadSchema() {
  try {
    const res = await fetch('/api/schema');
    const json = await res.json();
    if (!json.success) return;

    allSchemaTables = json.data.tables;
    document.getElementById('schema-table-count').innerText = `${allSchemaTables.length} Tables / Views`;
    renderSchemaTables(allSchemaTables);
  } catch (err) {
    console.error('Failed to load schema:', err);
  }
}

function renderSchemaTables(tables) {
  const tbody = document.getElementById('schema-tables-tbody');
  tbody.innerHTML = tables.map(t => `
    <tr>
      <td><code>${t.table_name}</code></td>
      <td><span class="badge ${t.table_type === 'BASE TABLE' ? 'badge-blue' : 'badge-slate'}">${t.table_type}</span></td>
      <td>${Number(t.approx_rows || 0).toLocaleString()}</td>
      <td>${formatBytes(t.data_bytes || 0)}</td>
      <td>${formatBytes(t.index_bytes || 0)}</td>
    </tr>
  `).join('');
}

function filterSchemaTables() {
  const q = document.getElementById('schema-search-input').value.toLowerCase().trim();
  const filtered = allSchemaTables.filter(t => t.table_name.toLowerCase().includes(q));
  renderSchemaTables(filtered);
}

// ============================================================================
// Modal & Utility Helpers
// ============================================================================
function openModal(modalId) {
  const m = document.getElementById(modalId);
  if (m) m.classList.add('open');
}

function closeModal(modalId) {
  const m = document.getElementById(modalId);
  if (m) m.classList.remove('open');
}

function getInitials(name) {
  if (!name) return '??';
  const parts = name.trim().split(/\s+/);
  if (parts.length === 1) return parts[0].substring(0, 2).toUpperCase();
  return (parts[0][0] + parts[parts.length - 1][0]).toUpperCase();
}

function formatBytes(bytes) {
  if (bytes === 0) return '0 B';
  const k = 1024;
  const sizes = ['B', 'KB', 'MB', 'GB'];
  const i = Math.floor(Math.log(bytes) / Math.log(k));
  return parseFloat((bytes / Math.pow(k, i)).toFixed(1)) + ' ' + sizes[i];
}

function escapeHtml(str) {
  if (str === null || str === undefined) return '';
  return String(str)
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#39;');
}
