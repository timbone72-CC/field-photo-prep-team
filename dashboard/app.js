const SUPABASE_URL = 'https://vyocaujuwrivoqynvitm.supabase.co';
const SUPABASE_PUBLISHABLE_KEY = 'sb_publishable_UPmj_Y10-mLwJo7soekCpg_BYZ08LNZ';

let accessToken = null;
let currentUser = null;
let assignableUsers = [];
let workOrderRows = [];

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

const createForm = document.getElementById('create-wo-form');
const createButton = document.getElementById('create-wo');
const createStatus = document.getElementById('create-status');
const woNumberInput = document.getElementById('wo-number');
const propertyAddressInput = document.getElementById('property-address');
const workTypeInput = document.getElementById('work-type');
const instructionsInput = document.getElementById('instructions');
const dueDateInput = document.getElementById('due-date');
const assigneeSelect = document.getElementById('assignee');

const editSection = document.getElementById('edit-work-order-section');
const editForm = document.getElementById('edit-wo-form');
const editWorkOrderIdInput = document.getElementById('edit-work-order-id');
const editWoNumberInput = document.getElementById('edit-wo-number');
const editPropertyAddressInput = document.getElementById('edit-property-address');
const editWorkTypeInput = document.getElementById('edit-work-type');
const editInstructionsInput = document.getElementById('edit-instructions');
const editDueDateInput = document.getElementById('edit-due-date');
const editAssigneeSelect = document.getElementById('edit-assignee');
const editReassignNote = document.getElementById('edit-reassign-note');
const saveEditButton = document.getElementById('save-edit');
const cancelEditButton = document.getElementById('cancel-edit');
const editStatus = document.getElementById('edit-status');

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

    const [rows, users] = await Promise.all([
      fetchWorkOrders(),
      fetchAssignableUsers()
    ]);

    verifyAdminRls(rows, metadata.organization_id);
    renderSignedIn(rows, users, metadata.organization_id);
  } catch (error) {
    accessToken = null;
    currentUser = null;
    assignableUsers = [];
    workOrderRows = [];
    passwordInput.value = '';
    setLoginStatus(error instanceof Error ? error.message : 'Sign-in failed.', true);
  }
});

createForm.addEventListener('submit', async (event) => {
  event.preventDefault();
  setCreateStatus('Creating work order…', false);
  createButton.disabled = true;

  try {
    const createdRows = await createWorkOrder({
      woNumber: woNumberInput.value.trim(),
      propertyAddress: propertyAddressInput.value.trim(),
      workType: workTypeInput.value.trim(),
      instructions: instructionsInput.value.trim(),
      dueDate: dueDateInput.value,
      assignedUserId: assigneeSelect.value
    });

    const created = Array.isArray(createdRows) ? createdRows[0] : null;
    if (!created || !created.work_order_id) {
      throw new Error('The server did not return the created work order.');
    }

    setCreateStatus(`Created and assigned ${created.wo_number}.`, false);
    createForm.reset();
    fillAssigneeSelect(assigneeSelect, assignableUsers, 'Choose Team user');

    await refreshWorkOrders();
  } catch (error) {
    setCreateStatus(error instanceof Error ? error.message : 'Unable to create work order.', true);
  } finally {
    createButton.disabled = false;
  }
});

editForm.addEventListener('submit', async (event) => {
  event.preventDefault();
  setEditStatus('Saving changes…', false);
  saveEditButton.disabled = true;

  try {
    const updatedRows = await updateWorkOrder({
      workOrderId: editWorkOrderIdInput.value,
      woNumber: editWoNumberInput.value.trim(),
      propertyAddress: editPropertyAddressInput.value.trim(),
      workType: editWorkTypeInput.value.trim(),
      instructions: editInstructionsInput.value.trim(),
      dueDate: editDueDateInput.value,
      assignedUserId: editAssigneeSelect.value
    });

    const updated = Array.isArray(updatedRows) ? updatedRows[0] : null;
    if (!updated || !updated.work_order_id) {
      throw new Error('The server did not return the updated work order.');
    }

    await refreshWorkOrders();
    setEditStatus(`Saved ${updated.wo_number}.`, false);
  } catch (error) {
    setEditStatus(error instanceof Error ? error.message : 'Unable to update work order.', true);
  } finally {
    saveEditButton.disabled = false;
  }
});

cancelEditButton.addEventListener('click', () => {
  closeEditor();
});

signOutButton.addEventListener('click', () => {
  accessToken = null;
  currentUser = null;
  assignableUsers = [];
  workOrderRows = [];
  workOrders.replaceChildren();
  rlsResult.textContent = '';
  accountHeading.textContent = 'Signed in';
  createForm.reset();
  fillAssigneeSelect(assigneeSelect, [], 'Sign in to load Team users');
  assigneeSelect.disabled = true;
  createStatus.textContent = '';
  closeEditor();
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
    'instructions',
    'due_date',
    'field_status',
    'created_at'
  ].join(',');

  // Intentionally broad request: no organization_id or assigned_user_id filter.
  // Supabase RLS is the authorization boundary for rows returned here.
  const response = await fetch(
    `${SUPABASE_URL}/rest/v1/work_orders?select=${encodeURIComponent(select)}&order=created_at.asc`,
    { headers: authHeaders() }
  );

  if (!response.ok) {
    throw new Error(await readableError(response, 'Unable to load work orders.'));
  }

  return response.json();
}

async function fetchAssignableUsers() {
  requireAccessToken();
  const response = await fetch(`${SUPABASE_URL}/rest/v1/rpc/admin_list_assignable_users`, {
    method: 'POST',
    headers: authHeaders(true),
    body: '{}'
  });

  if (!response.ok) {
    throw new Error(await readableError(response, 'Unable to load Team users.'));
  }

  return response.json();
}

async function createWorkOrder({
  woNumber,
  propertyAddress,
  workType,
  instructions,
  dueDate,
  assignedUserId
}) {
  requireAccessToken();

  const response = await fetch(`${SUPABASE_URL}/rest/v1/rpc/admin_create_work_order`, {
    method: 'POST',
    headers: authHeaders(true),
    body: JSON.stringify({
      p_wo_number: woNumber,
      p_property_address: propertyAddress,
      p_work_type: workType,
      p_instructions: instructions || null,
      p_due_date: dueDate,
      p_assigned_user_id: assignedUserId
    })
  });

  if (!response.ok) {
    throw new Error(await readableError(response, 'Unable to create work order.'));
  }

  return response.json();
}

async function updateWorkOrder({
  workOrderId,
  woNumber,
  propertyAddress,
  workType,
  instructions,
  dueDate,
  assignedUserId
}) {
  requireAccessToken();

  const response = await fetch(`${SUPABASE_URL}/rest/v1/rpc/admin_update_work_order`, {
    method: 'POST',
    headers: authHeaders(true),
    body: JSON.stringify({
      p_work_order_id: workOrderId,
      p_wo_number: woNumber,
      p_property_address: propertyAddress,
      p_work_type: workType,
      p_instructions: instructions || null,
      p_due_date: dueDate,
      p_assigned_user_id: assignedUserId
    })
  });

  if (!response.ok) {
    throw new Error(await readableError(response, 'Unable to update work order.'));
  }

  return response.json();
}

async function refreshWorkOrders() {
  const metadata = currentUser.app_metadata || {};
  const rows = await fetchWorkOrders();
  verifyAdminRls(rows, metadata.organization_id);
  workOrderRows = rows;
  renderRlsSummary(rows);
  renderWorkOrders(rows, metadata.organization_id);
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

function renderSignedIn(rows, users, organizationId) {
  loginCard.classList.add('hidden');
  resultsCard.classList.remove('hidden');
  accountHeading.textContent = `Signed in as ${currentUser.email}`;

  assignableUsers = users;
  workOrderRows = rows;

  renderRlsSummary(rows);
  renderAssignableUsers(users);
  renderWorkOrders(rows, organizationId);
}

function renderRlsSummary(rows) {
  rlsResult.className = 'check pass';
  rlsResult.textContent =
    `RLS CHECK: PASS\nServer returned ${rows.length} in-organization work order(s). ` +
    'Required Team control rows are visible to Admin, the other-organization control is hidden, ' +
    'and no client-side organization filter was used.';
}

function renderAssignableUsers(users) {
  if (!Array.isArray(users) || users.length === 0) {
    throw new Error('No assignable Team users were returned.');
  }

  fillAssigneeSelect(assigneeSelect, users, 'Choose Team user');
  assigneeSelect.disabled = false;
}

function fillAssigneeSelect(select, users, placeholder, selectedUserId = '') {
  select.replaceChildren(new Option(placeholder, ''));
  for (const user of users) {
    const option = new Option(`${user.email} (${user.role})`, user.user_id);
    option.selected = user.user_id === selectedUserId;
    select.add(option);
  }
  if (selectedUserId) {
    select.value = selectedUserId;
  }
}

function renderWorkOrders(rows, organizationId) {
  workOrders.replaceChildren();
  const userById = new Map(assignableUsers.map((user) => [user.user_id, user]));

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

    const assignee = document.createElement('p');
    assignee.className = 'muted';
    const assignedUser = userById.get(row.assigned_user_id);
    assignee.textContent = `Assigned: ${assignedUser ? `${assignedUser.email} (${assignedUser.role})` : 'Team user'}`;

    const instructions = document.createElement('p');
    instructions.className = 'muted';
    instructions.textContent = `Instructions: ${row.instructions || 'None'}`;

    const actions = document.createElement('div');
    actions.className = 'work-order-actions';

    const editButton = document.createElement('button');
    editButton.type = 'button';
    editButton.className = 'secondary';
    editButton.textContent = row.field_status === 'ASSIGNED' ? 'Edit / Reassign' : 'Edit';
    editButton.addEventListener('click', () => openEditor(row.id));

    actions.append(editButton);
    article.append(title, address, details, assignee, instructions, actions);
    workOrders.append(article);
  }

  const orgNote = document.createElement('p');
  orgNote.className = 'tiny muted';
  orgNote.textContent = `Verified organization: ${organizationId}`;
  workOrders.append(orgNote);
}

function openEditor(workOrderId) {
  const row = workOrderRows.find((item) => item.id === workOrderId);
  if (!row) {
    setEditStatus('Work order is no longer available in the current list.', true);
    return;
  }

  editWorkOrderIdInput.value = row.id;
  editWoNumberInput.value = row.wo_number;
  editPropertyAddressInput.value = row.property_address;
  editWorkTypeInput.value = row.work_type;
  editInstructionsInput.value = row.instructions || '';
  editDueDateInput.value = row.due_date;

  fillAssigneeSelect(editAssigneeSelect, assignableUsers, 'Choose Team user', row.assigned_user_id);
  editAssigneeSelect.disabled = row.field_status !== 'ASSIGNED';

  if (row.field_status === 'ASSIGNED') {
    editReassignNote.textContent = 'Reassignment is allowed while field status is ASSIGNED.';
  } else {
    editReassignNote.textContent =
      `Reassignment is locked because field status is ${row.field_status}. Dispatch details may still be corrected.`;
  }

  setEditStatus('', false);
  editSection.classList.remove('hidden');
  editSection.scrollIntoView({ behavior: 'smooth', block: 'start' });
}

function closeEditor() {
  editForm.reset();
  editWorkOrderIdInput.value = '';
  editAssigneeSelect.replaceChildren(new Option('Choose Team user', ''));
  editAssigneeSelect.disabled = true;
  editReassignNote.textContent = '';
  editStatus.textContent = '';
  editSection.classList.add('hidden');
}

function authHeaders(withJson = false) {
  const headers = {
    apikey: SUPABASE_PUBLISHABLE_KEY,
    Authorization: `Bearer ${accessToken}`
  };

  if (withJson) {
    headers['Content-Type'] = 'application/json';
  }

  return headers;
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

function setCreateStatus(message, isError) {
  createStatus.textContent = message;
  createStatus.classList.toggle('error', isError);
}

function setEditStatus(message, isError) {
  editStatus.textContent = message;
  editStatus.classList.toggle('error', isError);
}
