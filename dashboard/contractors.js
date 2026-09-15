const SUPABASE_URL = 'https://vyocaujuwrivoqynvitm.supabase.co';
const SUPABASE_PUBLISHABLE_KEY = 'sb_publishable_UPmj_Y10-mLwJo7soekCpg_BYZ08LNZ';
const ADMIN_SESSION_STORAGE_KEY = 'fppTeamAdmin.tabAuthSession';
const INVITE_FUNCTION_URL = `${SUPABASE_URL}/functions/v1/admin-invite-contractor`;

let accessToken = null;
let refreshToken = null;

const authStatus = document.getElementById('auth-status');
const contractorSection = document.getElementById('contractor-section');
const seatSummary = document.getElementById('seat-summary');
const inviteForm = document.getElementById('invite-form');
const nameInput = document.getElementById('contractor-name');
const emailInput = document.getElementById('contractor-email');
const inviteButton = document.getElementById('invite-contractor');
const inviteStatus = document.getElementById('invite-status');

boot();

inviteForm.addEventListener('submit', async (event) => {
  event.preventDefault();
  inviteButton.disabled = true;
  setInviteStatus('Sending invitation…', false);

  try {
    await ensureFreshSession();
    const response = await fetch(INVITE_FUNCTION_URL, {
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

    setInviteStatus(
      `Invitation sent to ${payload.email}. The seat is reserved until account setup is completed.`,
      false
    );
    inviteForm.reset();
    await loadSeatSummary();
  } catch (error) {
    setInviteStatus(error instanceof Error ? error.message : 'Unable to send Contractor invitation.', true);
  } finally {
    inviteButton.disabled = false;
  }
});

async function boot() {
  try {
    const session = readAdminSession();
    if (!session) {
      throw new Error('No Admin tab session is available. Open Work Orders and sign in first.');
    }

    accessToken = session.access_token;
    refreshToken = session.refresh_token;
    await ensureFreshSession();

    const user = await fetchCurrentUser();
    const metadata = user.app_metadata || {};
    if (metadata.role !== 'ADMIN' || !metadata.organization_id) {
      throw new Error('This account is not authorized as a Team Admin.');
    }

    authStatus.className = 'check pass';
    authStatus.textContent = `ADMIN SESSION: VERIFIED\n${user.email}`;
    contractorSection.classList.remove('hidden');
    await loadSeatSummary();
  } catch (error) {
    authStatus.className = 'check';
    authStatus.textContent = error instanceof Error ? error.message : 'Unable to verify Admin session.';
    contractorSection.classList.add('hidden');
  }
}

async function loadSeatSummary() {
  await ensureFreshSession();
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

  const pendingText = Number(summary.pending_invitations) > 0
    ? ` • ${summary.pending_invitations} pending invitation(s)`
    : '';

  seatSummary.textContent =
    `${summary.used_seats} of ${summary.seat_limit} contractor seats in use/reserved` + pendingText;

  inviteButton.disabled = Number(summary.available_seats) <= 0;
  if (Number(summary.available_seats) <= 0 && !inviteStatus.textContent) {
    setInviteStatus('No Contractor seat is currently available.', false);
  }
}

async function fetchCurrentUser() {
  const response = await fetch(`${SUPABASE_URL}/auth/v1/user`, {
    headers: authHeaders(false)
  });

  if (!response.ok) {
    throw new Error(await readableError(response, 'Unable to verify the Admin session.'));
  }
  return response.json();
}

function authHeaders(json = false) {
  const headers = {
    apikey: SUPABASE_PUBLISHABLE_KEY,
    Authorization: `Bearer ${accessToken}`
  };
  if (json) headers['Content-Type'] = 'application/json';
  return headers;
}

async function ensureFreshSession() {
  const stored = readAdminSession();
  if (!stored) {
    throw new Error('Your Admin tab session ended. Return to Work Orders and sign in again.');
  }

  accessToken = stored.access_token;
  refreshToken = stored.refresh_token;

  const expiresAt = Number(stored.expires_at);
  if (!Number.isFinite(expiresAt) || Math.floor(Date.now() / 1000) < expiresAt - 30) {
    return;
  }

  const response = await fetch(`${SUPABASE_URL}/auth/v1/token?grant_type=refresh_token`, {
    method: 'POST',
    headers: {
      apikey: SUPABASE_PUBLISHABLE_KEY,
      'Content-Type': 'application/json'
    },
    body: JSON.stringify({ refresh_token: refreshToken })
  });

  if (!response.ok) {
    clearAdminSession();
    throw new Error(await readableError(response, 'Unable to refresh the Admin session.'));
  }

  const session = await response.json();
  if (!session.access_token || !session.refresh_token) {
    throw new Error('Supabase did not return a complete refreshed session.');
  }

  const next = {
    access_token: session.access_token,
    refresh_token: session.refresh_token,
    expires_at: Number(session.expires_at) || Math.floor(Date.now() / 1000) + Number(session.expires_in || 3600)
  };
  sessionStorage.setItem(ADMIN_SESSION_STORAGE_KEY, JSON.stringify(next));
  accessToken = next.access_token;
  refreshToken = next.refresh_token;
}

function readAdminSession() {
  try {
    const raw = sessionStorage.getItem(ADMIN_SESSION_STORAGE_KEY);
    if (!raw) return null;
    const session = JSON.parse(raw);
    if (!session.access_token || !session.refresh_token) return null;
    return session;
  } catch {
    return null;
  }
}

function clearAdminSession() {
  try {
    sessionStorage.removeItem(ADMIN_SESSION_STORAGE_KEY);
  } catch {
    // Nothing else is required if storage is unavailable.
  }
}

async function readableError(response, fallback) {
  try {
    const body = await response.json();
    return body.error_description || body.msg || body.message || body.error || fallback;
  } catch {
    return fallback;
  }
}

function setInviteStatus(message, isError) {
  inviteStatus.textContent = message;
  inviteStatus.className = isError ? 'status error' : 'status';
}
