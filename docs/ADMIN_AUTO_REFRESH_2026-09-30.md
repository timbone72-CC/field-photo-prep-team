# Admin Automatic Refresh — 2026-09-30

## Classification and ownership

Scope key: `admin-auto-refresh`. Level 2 — client visibility and reuse of the existing Admin session-refresh endpoint; no new server authorization authority or credential storage.

Operator request: work orders and Contractor receipt confirmations should appear without refreshing the dashboard manually.

Authoritative branch: `feat/admin-auto-refresh`, from main `5757dbc02e712eea70ace7763f5ddae2b38712b2`. Required packs: AGENTS, GOVERNANCE, PROJECT_PROFILE, RULE_INDEX, CHANGE_CONTROL, TESTING, INTEGRATION, Phase 2/Phase 3 roadmap and phase-staging doctrine.

PR #20 remains the independent Level 3 onboarding owner. PR #17 remains the Android Room/session owner; this slice does not change an Android file or create a second cache/session path. The requested phone automatic-refresh behavior must be reconciled in that existing line. The original FPP is excluded.

## Behavior and boundaries

- `dashboard/auto-refresh.js` refreshes the visible, online, signed-in Admin view every 15 seconds and on return/focus/network recovery.
- It reads the existing broad RLS-protected work-order endpoint and existing assignable-user, seat and pending-invitation RPCs. It never sends a create, edit, invite or cancellation request itself.
- It renders the work-order list only for changed data, preserves form input/selected Contractor/scroll, and warns about a server change to an open edited order. An unavailable previously selected Contractor remains visible as unavailable; the server still decides whether an eventual submitted assignment is valid.
- Polls cannot overlap. A snapshot raced by a dispatch mutation or another login is ignored. Temporary network failure preserves the last received view and retries; hidden/offline/signed-out pages do not poll.
- `dashboard/session.js` is still the only browser credential-storage owner. It rotates an expiring token before authenticated requests, shares concurrent rotations, checks the refreshed Admin identity/org, and ignores late responses from a former login. Requests have a 30-second timeout; an unauthorized request/rejected refresh signs out. Mutations are never automatically retried.
- Existing APIs, RLS, role/org checks, seat/activation rules, assignment ownership, consent and receipt meaning remain unchanged. No schema, Edge Function, Auth URL, project identity, package/signer or photo/Drive change.
- The new UI statement is only automatic-update/temporary stale-data status. There is no preference/settings screen, Realtime service or background worker.

## Verification and handoff

Focused local tests: 15 passing tests for visible/hidden/offline scheduling, unchanged snapshots, receipt updates, retained drafts/selections/scroll, unavailable assignees, overlapping polls, dispatch/sign-out/body races, concurrent token rotation, temporary and rejected refresh, wrong-organization data and no automatic mutation replay. Changed JavaScript syntax and diff/credential-storage checks pass.

Required GitHub `governance`, `build` and `dashboard` checks passed on runtime head `06484614119d327797f9c87d49a65221dadfcc33`: runs 36799036071, 36799035878 and 36799035910 respectively. The evidence-only checkpoint commit must receive its own required checks before merge.

Authenticated laptop browser checks on the published candidate at `http://127.0.0.1:3100/`, using only disposable `FPP-000001`:

- At 20:51:27 America/Chicago, the operator confirmed an external saved `SERVER UPDATE TEST` instructions change appeared automatically in the candidate WO card while its unsaved `AUTO REFRESH TEST` editor text remained. Automatic server updates and retained drafts: PASS.
- At 21:30:28, the operator reported the test dashboard showed Contractor receipt `Received`. Asked whether it changed on its own or was already present when opened, the operator answered `on it own` at 21:31:18. Automatic receipt display: PASS by operator observation. No independently measured polling latency or agent-observed browser capture is claimed.
- The operator clarified that the phone was signed into the other existing Contractor before the final receipt test. Earlier account assumptions were incorrect; do not use those assumptions as proof of an account-specific reassignment or exact installed APK revision. No credentials or Contractor email addresses are recorded here.
- The earlier stale hosted dashboard was the existing Pages version without this feature. The cloud preview was blocked before sign-in; the actual successful checks were on the operator's laptop. A proposed phone start-work action was unavailable, so no IN_PROGRESS test is claimed.

The browser receipt/update/draft gate is complete. No additional invitation or live customer work was created. Android automatic refresh remains separate.

Existing live setup evidence: the new Contractor's password setup, ACCEPTED authority, Admin dropdown and Android sign-in passed. The operator additionally reported phone delivery and Admin receipt for disposable `FPP-000001`, address `FWH SETUP TEST`, work type `TEST ONLY`; a read-only Team check confirmed ASSIGNED, assigned to the setup fixture, receipt present and no pending handoff. The account-specific reassignment/consent evidence for PR #20 remains a separate gate; this automatic-refresh smoke does not claim to close it.

## Rollback and status

Rollback: revert only this feature to main `5757dbc02e712eea70ace7763f5ddae2b38712b2`. Preserve Auth accounts, invitations, test work and any real data. No live backend/configuration rollback is needed because this source change does not modify them.

Status: candidate implementation, focused checks, runtime-head CI and authenticated operator browser smoke complete; checkpoint-head CI, merge and Pages deployment pending. Repo rename, Android auto-refresh and original FPP changes are not completed by this slice.
