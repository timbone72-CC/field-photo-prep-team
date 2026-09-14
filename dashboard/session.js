const ADMIN_SESSION_STORAGE_KEY = 'fppTeamAdmin.tabAuthSession';

let pendingAdminSession = null;

const originalSignInWithPassword = signInWithPassword;
signInWithPassword = async function persistedSignInWithPassword(email, password) {
  const session = await originalSignInWithPassword(email, password);
  pendingAdminSession = session;
  return session;
};

const originalRenderSignedIn = renderSignedIn;
renderSignedIn = function persistedRenderSignedIn(rows, users, organizationId) {
  const metadata = currentUser && currentUser.app_metadata ? currentUser.app_metadata : {};
  if (pendingAdminSession && metadata.role === 'ADMIN' && metadata.organization_id) {
    storeAdminSession(pendingAdminSession);
    pendingAdminSession = null;
  }
  return originalRenderSignedIn(rows, users, organizationId);
};

signOutButton.addEventListener('click', () => {
  pendingAdminSession = null;
  clearAdminSession();
});

restoreAdminSession();

async function restoreAdminSession() {
  const stored = readAdminSession();
  if (!stored) {
    return;
  }

  setLoginStatus('Restoring Admin session…', false);

  try {
    let session = stored;
    if (sessionNeedsRefresh(session)) {
      session = await refreshAdminSession(session.refresh_token);
      storeAdminSession(session);
    }

    accessToken = session.access_token;

    try {
      currentUser = await fetchCurrentUser();
    } catch (firstError) {
      session = await refreshAdminSession(session.refresh_token);
      storeAdminSession(session);
      accessToken = session.access_token;
      currentUser = await fetchCurrentUser();
    }

    const metadata = currentUser.app_metadata || {};
    if (metadata.role !== 'ADMIN' || !metadata.organization_id) {
      throw new Error('Stored session is not authorized as a Team Admin.');
    }

    const [rows, users] = await Promise.all([
      fetchWorkOrders(),
      fetchAssignableUsers()
    ]);

    verifyAdminRls(rows, metadata.organization_id);
    renderSignedIn(rows, users, metadata.organization_id);
    setLoginStatus('', false);
  } catch (error) {
    clearAdminSession();
    pendingAdminSession = null;
    accessToken = null;
    currentUser = null;
    assignableUsers = [];
    workOrderRows = [];
    setLoginStatus('Your dashboard session could not be restored. Sign in again.', false);
  }
}

async function refreshAdminSession(refreshToken) {
  if (!refreshToken) {
    throw new Error('No refresh token is available.');
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
    throw new Error(await readableError(response, 'Unable to refresh the Admin session.'));
  }

  const session = await response.json();
  if (!session.access_token || !session.refresh_token) {
    throw new Error('Supabase did not return a complete refreshed session.');
  }
  return session;
}

function storeAdminSession(session) {
  if (!session || !session.access_token || !session.refresh_token) {
    return;
  }

  const expiresAt = Number(session.expires_at)
    || Math.floor(Date.now() / 1000) + Number(session.expires_in || 3600);

  const stored = {
    access_token: session.access_token,
    refresh_token: session.refresh_token,
    expires_at: expiresAt
  };

  try {
    sessionStorage.setItem(ADMIN_SESSION_STORAGE_KEY, JSON.stringify(stored));
  } catch {
    // Tab-session persistence is a convenience only; normal sign-in still works without it.
  }
}

function readAdminSession() {
  try {
    const raw = sessionStorage.getItem(ADMIN_SESSION_STORAGE_KEY);
    if (!raw) {
      return null;
    }

    const session = JSON.parse(raw);
    if (!session.access_token || !session.refresh_token) {
      clearAdminSession();
      return null;
    }
    return session;
  } catch {
    clearAdminSession();
    return null;
  }
}

function clearAdminSession() {
  try {
    sessionStorage.removeItem(ADMIN_SESSION_STORAGE_KEY);
  } catch {
    // Nothing else is required if browser storage is unavailable.
  }
}

function sessionNeedsRefresh(session) {
  const expiresAt = Number(session && session.expires_at);
  if (!Number.isFinite(expiresAt) || expiresAt <= 0) {
    return false;
  }
  return Math.floor(Date.now() / 1000) >= expiresAt - 30;
}
