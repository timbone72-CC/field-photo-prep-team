const CONTRACTOR_INVITE_FUNCTION_URL = `${SUPABASE_URL}/functions/v1/admin-invite-contractor`;

let contractorManagementReady = false;
let contractorSeatAvailable = false;
let contractorSeatSummary = null;
let pendingContractorInvitations = [];

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
    <div id="pending-contractor-invitations" class="work-orders" aria-live="polite"></div>
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

  const [summary, pendingInvitations] = await Promise.all([
    fetchContractorSeatSummary(),
    fetchPendingContractorInvitations()
  ]);

  contractorSeatSummary = summary;
  pendingContractorInvitations = pendingInvitations;
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

  renderPendingContractorInvitations(pendingContractorInvitations);

  if (refreshAssignees) {
    const users = await fetchAssignableUsers();
    assignableUsers = users;
    renderAssignableUsers(users);
  }
}

async function fetchContractorSeatSummary() {
  const response = await fetch(`${SUPABASE_URL}/rest/v1/rpc/admin_get_contractor_seat_summary`, {
    method: 'POST',
    headers: authHeaders(true),
    body: '{}'
  });

  if (!response.ok) {
    throw new Error(await readableError(response, 'Unable to load Contractor seats.'));
  }

  const rows = await response.json();
  const summary = Array.isArray(rows) ? rows[0] : null;
  if (!summary) {
    throw new Error('The server did not return Contractor seat information.');
  }
  return summary;
}

async function fetchPendingContractorInvitations() {
  const response = await fetch(`${SUPABASE_URL}/rest/v1/rpc/admin_list_pending_contractor_invitations`, {
    method: 'POST',
    headers: authHeaders(true),
    body: '{}'
  });

  if (!response.ok) {
    throw new Error(await readableError(response, 'Unable to load pending Contractor invitations.'));
  }

  const rows = await response.json();
  return Array.isArray(rows) ? rows : [];
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
        operation: 'invite',
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

function renderPendingContractorInvitations(invitations) {
  const container = document.getElementById('pending-contractor-invitations');
  if (!container) return;

  container.replaceChildren();

  const heading = document.createElement('h3');
  heading.textContent = 'Pending Invitations';
  container.append(heading);

  if (!Array.isArray(invitations) || invitations.length === 0) {
    const empty = document.createElement('p');
    empty.className = 'muted';
    empty.textContent = 'No pending Contractor invitations.';
    container.append(empty);
    return;
  }

  for (const invitation of invitations) {
    const article = document.createElement('article');
    article.className = 'work-order';

    const title = document.createElement('h3');
    title.textContent = invitation.display_name || 'Contractor invitation';

    const email = document.createElement('p');
    email.textContent = invitation.email;

    const details = document.createElement('p');
    details.className = 'muted';
    details.textContent = `Status: ${invitation.status} • Sent/reserved: ${formatTimestamp(invitation.created_at)}`;

    const cancelButton = document.createElement('button');
    cancelButton.type = 'button';
    cancelButton.className = 'secondary';
    cancelButton.textContent = invitation.status === 'CANCELLING'
      ? 'Cancellation Pending'
      : 'Cancel Invitation';
    cancelButton.disabled = invitation.status === 'CANCELLING';
    cancelButton.addEventListener('click', () => handleContractorInvitationCancel(invitation, cancelButton));

    article.append(title, email, details, cancelButton);
    container.append(article);
  }
}

async function handleContractorInvitationCancel(invitation, cancelButton) {
  const label = invitation.email || invitation.display_name || 'this invitation';
  const confirmed = window.confirm(
    `Cancel the pending invitation to ${label}?\n\n` +
    'If the invited account is still unused, Team will remove that disposable Auth identity and free the Contractor seat.'
  );

  if (!confirmed) return;

  cancelButton.disabled = true;
  setContractorInviteStatus(`Cancelling invitation to ${label}…`, false);

  try {
    const response = await fetch(CONTRACTOR_INVITE_FUNCTION_URL, {
      method: 'POST',
      headers: {
        apikey: SUPABASE_PUBLISHABLE_KEY,
        Authorization: `Bearer ${accessToken}`,
        'Content-Type': 'application/json'
      },
      body: JSON.stringify({
        operation: 'cancel',
        invitation_id: invitation.invitation_id
      })
    });

    const payload = await response.json().catch(() => ({}));
    if (!response.ok) {
      throw new Error(payload.error || 'Unable to cancel Contractor invitation.');
    }

    setContractorInviteStatus(`Invitation to ${payload.email || label} cancelled. Contractor seat released.`, false);
    await refreshContractorManagement(true);
  } catch (error) {
    setContractorInviteStatus(
      error instanceof Error ? error.message : 'Unable to cancel Contractor invitation.',
      true
    );
    await refreshContractorManagement(false).catch(() => {});
  }
}

function setContractorInviteStatus(message, isError) {
  const element = document.getElementById('contractor-invite-status');
  if (!element) return;
  element.textContent = message;
  element.className = isError ? 'status error' : 'status';
}
