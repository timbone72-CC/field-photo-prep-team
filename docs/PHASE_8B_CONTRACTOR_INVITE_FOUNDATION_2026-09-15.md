# Phase 8B Contractor Invite Foundation — 2026-09-15

## Classification

**Level 3 — Supabase Auth, role, organization, and seat authorization boundary.**

This slice intentionally pulls forward only the smallest real Phase 8B capability needed to create a legitimate second Contractor account and complete the remaining Phase 2 reassignment/receipt smoke.

Known-good rollback baseline: `5d8f0b6241c4ecb87eb0663ac6e99125334a9f26`.

## User-visible workflow

`Admin signs in → enters contractor name + email → Team checks a server-controlled seat cap → Team reserves one seat → trusted backend sends a real Supabase invitation → contractor opens the invitation and chooses their own password → Team marks the invitation accepted → contractor becomes assignable.`

The Admin never chooses, receives, stores, or sees the contractor password.

## Scope

This slice implements only:

- a server-controlled Contractor seat limit;
- pending invitation seat reservation;
- an Admin seat summary;
- a narrow Admin invite form in the existing dashboard;
- a trusted Supabase Edge Function for Auth-admin invitation work;
- server-controlled Contractor/org Auth metadata;
- a small contractor invitation-acceptance/password-setup page;
- explicit activation after password setup;
- assignable-user filtering so pending/unaccepted invites cannot receive work;
- enough status truth to complete the two-Contractor Phase 2 smoke.

This slice deliberately does **not** implement:

- resend invitation;
- cancel invitation;
- deactivation/reactivation;
- Contractor deletion;
- additional Admin creation;
- commercial billing/payment;
- arbitrary Admin seat-limit changes;
- Phase 3 Room/offline behavior;
- any V1/FPP change.

Those remain in the later full Phase 8B lifecycle slice.

## Authority model

### Supabase/Postgres owns

- organization seat limit;
- invitation reservation/status;
- active/pending seat counts;
- caller role/org checks;
- whether an invited account is allowed to become assignable.

### Supabase Auth owns

- invited user identity;
- email confirmation/invite session;
- the password chosen by the invited contractor;
- server-controlled app metadata for `CONTRACTOR` + organization.

### Supabase Edge Function owns

Only the trusted bridge that requires Auth-admin privilege:

- validate the authenticated Admin caller;
- reserve a seat through a narrow database RPC;
- call the real Supabase Auth Admin invite API;
- set server-controlled contractor/org app metadata;
- finalize or safely fail/reconcile the reservation.

The service/secret credential remains only in the trusted Edge Function environment and is never returned to or embedded in GitHub Pages, Android, or repository source.

### Browser owns

Only requesting the action with its normal Admin access token and rendering server truth. It cannot raise the seat cap or write Auth metadata directly.

## Server model

### `organizations.contractor_seat_limit`

Add a positive server-controlled integer seat cap. For the current internal pilot, initialize the cap to **2**, which supports the existing Contractor plus one legitimate test Contractor. There is no Admin UI to change this cap in this slice.

### `contractor_invitations`

Minimum fields:

- invitation UUID;
- organization UUID;
- normalized email;
- display name;
- status;
- Auth user UUID when known;
- creating Admin UUID;
- created/updated timestamps.

Initial statuses:

- `RESERVED` — seat durably reserved before calling Auth;
- `SENT` — real Auth invitation created/sent;
- `ACCEPTED` — invited user completed password setup and activation;
- `FAILED` — known-safe invitation failure released the pending seat;
- `PROBLEM` — an ambiguous/partially completed invitation requires reconciliation rather than blind duplicate invitation.

Future resend/cancel/expiry/deactivation behavior is outside this slice and may extend the status model deliberately later.

A same-organization email cannot have more than one live `RESERVED`/`SENT` invitation.

## Seat counting

`used seats = active confirmed Contractor Auth users + live RESERVED/SENT invitations`

The same invited user must never be double-counted after activation. Activation transitions the invitation to `ACCEPTED`, removing it from pending count while the now-confirmed Contractor counts as active.

Only active/confirmed same-organization Contractors can appear in `admin_list_assignable_users()`.

## Narrow database actions

### Admin reserve invite

A narrow Admin-only RPC:

- verifies authenticated `ADMIN` + organization claim;
- normalizes and validates email/name;
- locks the organization row while checking the cap;
- rejects an existing Auth email or duplicate live invitation;
- counts active Contractors + pending invitations;
- rejects when no seat is available;
- inserts `RESERVED` and returns invitation identity + seat summary.

### Mark sent / known failure / problem

Narrow server actions finalize the reserved invitation after the trusted Auth call. They never create Auth users themselves.

### Contractor activation

A narrow authenticated Contractor RPC runs only after the invite session has been established and password update succeeded. It verifies:

- `auth.uid()` matches the invitation Auth user;
- Auth/app metadata says `CONTRACTOR` in the same organization;
- email is confirmed;
- invitation is `SENT`;

then changes only that invitation to `ACCEPTED`.

## Trusted invite flow

The Edge Function requires a valid JWT.

1. Browser sends name/email and the normal Admin Bearer token.
2. Function verifies current caller identity/role/org from the server, not browser-provided role/org fields.
3. Function calls the seat-reservation RPC under the Admin identity.
4. Function uses its server-only Supabase Auth-admin credential to send `inviteUserByEmail`.
5. It immediately sets server-controlled `app_metadata.role = CONTRACTOR` and the exact organization UUID on the returned Auth user.
6. It marks the invitation `SENT` with that Auth UUID.
7. If Auth reports a known-safe failure and no Auth user exists, mark `FAILED` so the seat is released.
8. If outcome is ambiguous, attempt server-side reconciliation by email. If identity/outcome still cannot be proven, mark `PROBLEM` and do not blindly send another invite.

## Invitation acceptance

A small public GitHub Pages acceptance page will:

- accept only the real Supabase invite session returned from the invite link;
- remove Auth tokens from the visible URL as soon as they are captured;
- verify the invited user from Supabase before showing password controls;
- let the contractor choose their own password using the authenticated Supabase user endpoint;
- call the narrow activation RPC after password update succeeds;
- show success and instruct the contractor to sign in to the Team app;
- not persist the invite access/refresh token to localStorage;
- not expose any Admin/service secret.

The invite redirect URL must be an allowed Supabase Auth redirect destination. The connector currently does not expose hosted Auth URL configuration, so the code may be built/staged first. If the Team GitHub Pages invite URL is not already allowed, that single provider setting is a real configuration gate and must be added before sending the first test invitation.

## Failure behavior

- Seat full: no Auth invite attempt occurs.
- Duplicate existing user/live invitation: fail clearly; do not create another identity.
- Auth invite known failure: pending reservation becomes `FAILED`; seat is released.
- Ambiguous Auth result: fail closed as `PROBLEM`; do not blind resend.
- Metadata finalization failure after Auth user creation: preserve `PROBLEM`; account does not become assignable.
- Invite link not accepted: remains pending and consumes a seat in this early slice. Expiry cleanup belongs to the full lifecycle implementation; the internal test invite will be completed immediately.
- Password setup failure: account remains non-assignable; evidence/reservation is preserved.
- Activation failure: account remains non-assignable until corrected.

## Protected behavior

- Admin account can never become a WO assignee.
- Seat limit is server-enforced.
- Browser/Android never receives Auth Admin/service credentials.
- Organization and role are server-controlled authorization facts.
- Pending invite is not assignable.
- Existing Admin/Contractor users and WOs are not rewritten.
- Existing assignment receipt/reassignment rules stay unchanged.
- V1/FPP stays untouched.

## Verification plan

Automated/server checks:

- migration/repository history match;
- seat cap positive and server-controlled;
- Admin same-org reserve succeeds when seat available;
- Contractor/wrong role reserve fails;
- duplicate live invite fails;
- seat-full reserve fails before Auth work;
- active + pending seat counts do not double-count;
- pending invited user is absent from assignable users;
- accepted confirmed Contractor appears in assignable users;
- activation rejects wrong user/wrong org/unconfirmed user;
- direct broad invitation-table mutation remains unavailable to browser roles;
- Edge Function contains no committed secret and verifies Admin server-side;
- dashboard sends only name/email + normal bearer token;
- focused dashboard checks pass;
- complete Admin + Android CI passes once on exact final head;
- Supabase security/performance advisors checked after DDL.

Provider/device reality gate:

1. Admin opens the real dashboard on Galaxy S22.
2. Admin enters a disposable/test email they control and a test name.
3. Invitation email arrives.
4. Test account opens invite link and sets its own password.
5. Dashboard refresh shows seat usage and the new Contractor as assignable.
6. Reassign `TEST-0003-DASHBOARD` from the original Contractor to test Contractor.
7. Original Contractor app refresh proves the WO disappears and receipt is reset.
8. Admin reassigns it back.
9. Original Contractor app receives it again and assignment receipt confirms.
10. If practical, use the same test Contractor for one real `IN_PROGRESS` approve/decline handoff.

## Merge gate

Because this is Level 3, the final exact runtime head must pass the planned checks and receive explicit operator approval before merge/deployment to the governed `main` state.
