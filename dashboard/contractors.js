const CONTRACTOR_INVITE_FUNCTION_URL = `${SUPABASE_URL}/functions/v1/admin-invite-contractor`;

let contractorManagementReady = false;
let contractorSeatAvailable = false;
let contractorSeatSummary = null;

const renderSignedInBeforeContractors = renderSignedIn;
renderSignedIn = function renderSignedInWithContractors(rows, users, organizationId) {
  const result = renderSignedInBeforeContractors(rows, users, organizationId);
  ensureContractorManagementUi();
  refreshContractorManagement().catch((error) => {
    setContractorInviteStatus(
      error instanceof Error ? error.message : 'Unable to load Contractor seats.',
      true
    );
  });
  return result;
};

function ensureContractorManagementUi() {
  if (contractorManagementReady) return;

  const createSection = document.querySelector('#results-card .admin-action');
  if (!createSection) return;

  const section = document.createElement('section');
  section.className = 'admin-action';
  section.id = 'contractor-management-section';
  section.setAttribute('aria-labelledby', 'contractor-management-heading');
  section.innerHTML = `
    <h2 id="contractor-management-heading">Contractors</h2>
    <p class="muted">Invite a Contractor without choosing or seeing their password. Seats and account roles are enforced by the server.</p>
    <p id="contractor-seat-summary" class="muted">Loading Contractor seats…</p>
    <form id="contractor-invite-form" class="admin-form" autocomplete="off">
      <label>Contractor name
        <input id="contractor-invite-name" type="text" required maxlength="200" placeholder="Test Contractor">
      </label>
      <label>Contractor email
        <input id="contractor-invite-email" type="email" required maxlength="320" autocomplete="off" placeholder="contractor@example.com">
      </label>
      <div class="row gap edit-actions">
        <button id="contractor-invite-button" type="submit">Send Invitation</button>
        <button id="contractor-refresh-button" class="secondary" type="button">Refresh Contractors</button>
      </div>
      <p id="contractor-invite-status" class="status" role="status" aria-live="polite"></p>
    </form>
  `;

  createSection.parentNode.insertBefore(section, createSection);

  document.getElementById('contractor-invite-form').addEventListener('submit', handleContractorInvite);
  document.getElementById('contractor-refresh-button').addEventListener('click', async () => {
    const refreshButton = document.getElementById('contractor-refresh-button');
    refreshButton.disabled = true;
    setContractorInviteStatus('Refreshing Contractors…', false);
    try {
      await refreshContractorManagement(true);
      setContractorInviteStatus('Contractor list refreshed.', false);
    } catch (error) {
      setContractorInviteStatus(
        error instanceof Error ? error.message : 'Unable to refresh Contractors.',
        true
      );
    } finally {
      refreshButton.disabled = false;
    }
  });

  contractorManagementReady = true;
}

async function refreshContractorManagement(refreshAssignees = false) {
  if (!accessToken || !currentUser) {
    throw new Error('Admin authentication is required to manage Contractors.');
  }

  const metadata = currentUser.app_metadata || {};
  if (metadata.role !== 'ADMIN' || !metadata.organization_id) {
    throw new Error('Admin permission required.');
  }

  const response = await fetch(`${SUPABASE_URL}/rest/v1/rpc/admin_get_contractor_seat_summary`, {
    method: 'POST',
    headers: authHeaders(true),
    body: '{}'
  });

  if (!response.ok) {
    throw new Error(await readableError(response, 'Unable to load Contractor seats.'));
  }

  const rows = await response.json();
  contractorSeatSummary = Array.isArray(rows) ? rows[0] : null;
  if (!contractorSeatSummary) {
    throw new Error('The server did not return Contractor seat information.');
  }

  contractorSeatAvailable = Number(contractorSeatSummary.available_seats) > 0;
  const pendingCount = Number(contractorSeatSummary.pending_invitations || 0);
  const pendingText = pendingCount > 0 ? ` • ${pendingCount} pending invitation(s)` : '';

  const summaryElement = document.getElementById('contractor-seat-summary');
  const inviteButton = document.getElementById('contractor-invite-button');
  if (summaryElement) {
    summaryElement.textContent =
      `${contractorSeatSummary.used_seats} of ${contractorSeatSummary.seat_limit} contractor seats in use/reserved${pendingText}`;
  }
  if (inviteButton) {
    inviteButton.disabled = !contractorSeatAvailable;
  }

  if (refreshAssignees) {
    const users = await fetchAssignableUsers();
    assignableUsers = users;
    renderAssignableUsers(users);
  }
}

async function handleContractorInvite(event) {
  event.preventDefault();

  const nameInput = document.getElementById('contractor-invite-name');
  const emailInput = document.getElementById('contractor-invite-email');
  const inviteButton = document.getElementById('contractor-invite-button');

  if (!contractorSeatAvailable) {
    setContractorInviteStatus('No Contractor seat is currently available.', true);
    return;
  }

  inviteButton.disabled = true;
  setContractorInviteStatus('Sending invitation…', false);

  try {
    const response = await fetch(CONTRACTOR_INVITE_FUNCTION_URL, {
      method: 'POST',
      headers: {
        apikey: SUPABASE_PUBLISHABLE_KEY,
        Authorization: `Bearer ${accessToken}`,
        'Content-Type': 'application/json'
      },
      body: JSON.stringify({
        display_name: nameInput.value.trim(),
        email: emailInput.value.trim()
      })
    });

    const payload = await response.json().catch(() => ({}));
    if (!response.ok) {
      throw new Error(payload.error || 'Unable to send Contractor invitation.');
    }

    nameInput.value = '';
    emailInput.value = '';
    setContractorInviteStatus(
      `Invitation sent to ${payload.email}. The seat stays reserved until account setup is completed.`,
      false
    );
    await refreshContractorManagement(false);
  } catch (error) {
    setContractorInviteStatus(
      error instanceof Error ? error.message : 'Unable to send Contractor invitation.',
      true
    );
  } finally {
    inviteButton.disabled = !contractorSeatAvailable;
  }
}

function setContractorInviteStatus(message, isError) {
  const element = document.getElementById('contractor-invite-status');
  if (!element) return;
  element.textContent = message;
  element.className = isError ? 'status error' : 'status';
}
