const SUPABASE_URL = 'https://vyocaujuwrivoqynvitm.supabase.co';
const SUPABASE_PUBLISHABLE_KEY = 'sb_publishable_UPmj_Y10-mLwJo7soekCpg_BYZ08LNZ';

let accessToken = null;
let currentUser = null;

const loginCard = document.getElementById('login-card');
const resultsCard = document.getElementById('results-card');
const loginForm = document.getElementById('login-form');
const emailInput = document.getElementById('email');
const passwordInput = document.getElementById('password');
const loginStatus = document.getElementById('login-status');
const signOutButton = document.getElementById('sign-out');
const accountHeading = document.getElementById('account-heading');
const rlsResult = document.getElementById('rls-result');
const workOrders = document.getElementById('work-orders');

loginForm.addEventListener('submit', async (event) => {
  event.preventDefault();
  setLoginStatus('Signing in…', false);

  const email = emailInput.value.trim();
  const password = passwordInput.value;

  try {
    const session = await signInWithPassword(email, password);
    passwordInput.value = '';
    accessToken = session.access_token;

    currentUser = await fetchCurrentUser();
    const metadata = currentUser.app_metadata || {};

    if (metadata.role !== 'ADMIN' || !metadata.organization_id) {
      throw new Error('This account is not authorized as a Team Admin.');
    }

    const rows = await fetchWorkOrders();
    verifyAdminRls(rows, metadata.organization_id);
    renderSignedIn(rows, metadata.organization_id);
  } catch (error) {
    accessToken = null;
    currentUser = null;
    passwordInput.value = '';
    setLoginStatus(error instanceof Error ? error.message : 'Sign-in failed.', true);
  }
});

signOutButton.addEventListener('click', () => {
  accessToken = null;
  currentUser = null;
  workOrders.replaceChildren();
  rlsResult.textContent = '';
  accountHeading.textContent = 'Signed in';
  resultsCard.classList.add('hidden');
  loginCard.classList.remove('hidden');
  emailInput.focus();
  setLoginStatus('Signed out. Session was held in memory only.', false);
});

async function signInWithPassword(email, password) {
  const response = await fetch(`${SUPABASE_URL}/auth/v1/token?grant_type=password`, {
    method: 'POST',
    headers: {
      apikey: SUPABASE_PUBLISHABLE_KEY,
      'Content-Type': 'application/json'
    },
    body: JSON.stringify({ email, password })
  });

  if (!response.ok) {
    throw new Error(await readableError(response, 'Unable to sign in.'));
  }

  return response.json();
}

async function fetchCurrentUser() {
  requireAccessToken();
  const response = await fetch(`${SUPABASE_URL}/auth/v1/user`, {
    headers: authHeaders()
  });

  if (!response.ok) {
    throw new Error(await readableError(response, 'Unable to verify the signed-in user.'));
  }

  return response.json();
}

async function fetchWorkOrders() {
  requireAccessToken();
  const select = [
    'id',
    'organization_id',
    'assigned_user_id',
    'wo_number',
    'property_address',
    'work_type',
    'due_date',
    'field_status',
    'created_at'
  ].join(',');

  // Intentionally broad request: no organization_id or assigned_user_id filter.
  // Supabase RLS is the authorization boundary being tested here.
  const response = await fetch(
    `${SUPABASE_URL}/rest/v1/work_orders?select=${encodeURIComponent(select)}&order=created_at.asc`,
    { headers: authHeaders() }
  );

  if (!response.ok) {
    throw new Error(await readableError(response, 'Unable to load work orders.'));
  }

  return response.json();
}

function verifyAdminRls(rows, expectedOrganizationId) {
  if (!Array.isArray(rows)) {
    throw new Error('Unexpected work-order response.');
  }

  const wrongOrganization = rows.find((row) => row.organization_id !== expectedOrganizationId);
  if (wrongOrganization) {
    throw new Error('RLS CHECK FAILED: a work order from another organization was returned.');
  }

  const numbers = new Set(rows.map((row) => row.wo_number));
  if (!numbers.has('TEST-0001') || !numbers.has('TEST-0002-ADMIN-ONLY')) {
    throw new Error('RLS CHECK FAILED: expected in-organization test work orders were not both returned.');
  }

  if (numbers.has('TEST-OTHER-ORG-CONTROL')) {
    throw new Error('RLS CHECK FAILED: the other-organization control work order was returned.');
  }
}

function renderSignedIn(rows, organizationId) {
  loginCard.classList.add('hidden');
  resultsCard.classList.remove('hidden');
  accountHeading.textContent = `Signed in as ${currentUser.email}`;

  rlsResult.className = 'check pass';
  rlsResult.textContent =
    `RLS CHECK: PASS\nServer returned ${rows.length} in-organization work order(s). ` +
    'Both Team controls are visible to Admin, the other-organization control is hidden, ' +
    'and no client-side organization filter was used.';

  workOrders.replaceChildren();
  for (const row of rows) {
    const article = document.createElement('article');
    article.className = 'work-order';

    const title = document.createElement('h3');
    title.textContent = row.wo_number;

    const address = document.createElement('p');
    address.textContent = row.property_address;

    const details = document.createElement('p');
    details.className = 'muted';
    details.textContent = `Work type: ${row.work_type} • Due: ${row.due_date} • Status: ${row.field_status}`;

    article.append(title, address, details);
    workOrders.append(article);
  }

  const orgNote = document.createElement('p');
  orgNote.className = 'tiny muted';
  orgNote.textContent = `Verified organization: ${organizationId}`;
  workOrders.append(orgNote);
}

function authHeaders() {
  return {
    apikey: SUPABASE_PUBLISHABLE_KEY,
    Authorization: `Bearer ${accessToken}`
  };
}

function requireAccessToken() {
  if (!accessToken) {
    throw new Error('No authenticated session is available.');
  }
}

async function readableError(response, fallback) {
  try {
    const body = await response.json();
    return body.msg || body.message || body.error_description || body.error || fallback;
  } catch {
    return fallback;
  }
}

function setLoginStatus(message, isError) {
  loginStatus.textContent = message;
  loginStatus.classList.toggle('error', isError);
}
