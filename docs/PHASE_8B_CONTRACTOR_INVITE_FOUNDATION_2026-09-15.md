# Phase 8B Contractor Invite Foundation — 2026-09-15

## Classification

**Level 3 — Supabase Auth, role, organization, and seat authorization boundary.**

This slice pulls forward only the smallest real Phase 8B capability needed to create a legitimate second Contractor account and complete the remaining Phase 2 reassignment/receipt smoke.

Known-good rollback baseline: `5d8f0b6241c4ecb87eb0663ac6e99125334a9f26`.

## User-visible workflow

`Admin signs in → enters contractor name + email → Team checks a server-controlled seat cap → Team reserves one seat → trusted backend sends a real Supabase invitation → contractor opens the invitation and chooses their own password → Team marks the invitation accepted → contractor becomes assignable.`

The Admin never chooses, receives, stores, or sees the contractor password.

## Scope

Implemented in this slice:

- server-controlled Contractor seat limit;
- pending invitation seat reservation;
- Admin seat summary and invite controls in the existing dashboard session;
- trusted Supabase Edge Function for Auth-admin invitation work;
- server-controlled Contractor/org Auth metadata;
- public invitation acceptance/password-setup page;
- explicit activation after password setup;
- server-side assignability invariant for current and pending WO assignees;
- enough real account lifecycle to create a second Contractor for the Phase 2 smoke.

Deliberately deferred:

- resend invitation;
- cancel invitation;
- invitation-expiry cleanup;
- deactivation/reactivation;
- Contractor deletion;
- additional Admin creation;
- commercial billing/payment;
- Admin editing of seat limits;
- Phase 3 Room/offline behavior;
- any V1/FPP change.

## Authority model

### Supabase/Postgres owns

- organization seat limit;
- invitation reservation/status;
- active/pending seat counts;
- caller role/org checks;
- whether a Contractor is actually assignable;
- the work-order boundary that rejects non-assignable current/pending assignees.

### Supabase Auth owns

- invited user identity;
- invitation/email-confirmation session;
- password chosen by the invited contractor;
- server-controlled `CONTRACTOR` + organization app metadata.

### Trusted Edge Function owns

Only the bridge that requires Auth-admin privilege:

- validates the authenticated Admin caller;
- reserves a seat through a narrow caller-scoped RPC;
- calls Supabase Auth Admin `inviteUserByEmail`;
- writes server-controlled Contractor/org app metadata;
- finalizes, safely fails, or marks uncertain invitation state.

The service-role credential stays only in the Supabase Edge Function environment. It is never committed to GitHub or returned to GitHub Pages/Android.

### Browser owns

Only name/email input, normal Admin bearer authentication, rendering server truth, and invited-user password entry. It cannot raise the seat cap, write app metadata, or directly mutate invitation records.

## Server model

### `organizations.contractor_seat_limit`

Positive server-controlled integer. Internal pilot value is **2**, supporting the existing Contractor plus one legitimate test Contractor. No Admin control changes this value in this slice.

### `contractor_invitations`

Fields include invitation UUID, organization UUID, normalized email, display name, status, Auth user UUID when known, creating Admin UUID, and created/updated timestamps.

Statuses:

- `RESERVED` — seat reserved before Auth call;
- `SENT` — Auth invitation/user created and Team metadata finalized;
- `ACCEPTED` — invited contractor completed password setup and activation;
- `FAILED` — known-safe failure with no retained Auth user; seat released;
- `PROBLEM` — ambiguous/partial outcome; fail closed and keep the seat reserved.

A same-organization email cannot have more than one live `RESERVED`, `SENT`, or `PROBLEM` invitation.

## Seat counting

`used seats = active accepted Contractors + live RESERVED/SENT/PROBLEM invitations`

`PROBLEM` intentionally holds a seat because an ambiguous Auth outcome must not allow over-allocation.

Activation changes the invitation from `SENT` to `ACCEPTED`; that removes it from pending count while the confirmed Contractor begins counting as active, so the same person is not double-counted.

## Assignability invariant

`private.is_assignable_contractor(user, organization)` requires:

- Auth user exists and is not deleted;
- email is confirmed;
- account is not currently banned;
- exact organization metadata matches;
- role is `CONTRACTOR`;
- there is no invitation for that Auth user still in a non-`ACCEPTED` state.

This invariant is used by `admin_list_assignable_users()` and a `work_orders` trigger that validates both `assigned_user_id` and `pending_assignee_user_id`. Hiding a pending invitation in the dropdown is therefore not the security boundary; a modified client cannot assign that UUID either.

## Narrow database actions

- `admin_get_contractor_seat_summary()` — Admin-only seat truth.
- `admin_reserve_contractor_invitation(email, display_name)` — Admin-only reservation under organization-row lock; rejects duplicates and seat overflow before Auth work.
- `complete_contractor_invitation_activation()` — invited Contractor-only activation after confirmed Auth/session/password setup.
- `team_finalize_contractor_invitation(...)` — service-role-only finalization for `SENT`, known-safe `FAILED`, or fail-closed `PROBLEM`.

`contractor_invitations` has RLS enabled and authenticated/anon users have no direct table privileges.

## Trusted invite flow

1. Browser sends name/email with the normal Admin bearer token.
2. Edge Function verifies the actual caller through Supabase Auth and requires server metadata `ADMIN` + organization.
3. Caller-scoped client reserves a seat through the narrow Admin RPC.
4. Service client sends the real Supabase Auth invitation.
5. Returned Auth user gets server-controlled `role=CONTRACTOR` and exact organization UUID while preserving other app metadata.
6. Invitation is finalized `SENT` with the Auth UUID.
7. If the Auth call reports failure, reconciliation only accepts a user whose email **and** invitation marker match this reservation.
8. Proven no-user failure becomes `FAILED`; ambiguous/partial outcome becomes `PROBLEM` or remains `RESERVED`; no blind duplicate invite is sent.

## Invitation acceptance

`dashboard/contractor-invite.html` + `contractor-invite.js`:

- require the real Supabase invite session;
- remove access-token material from the visible URL immediately;
- verify current Auth user plus Team Contractor/org/invitation metadata;
- let the contractor choose their own password;
- call the activation RPC only after password update succeeds;
- require `ACCEPTED` confirmation before showing Account Ready;
- do not store invite tokens in localStorage/sessionStorage;
- expose no Admin/service credential.

The invite redirect target is:

`https://timbone72-cc.github.io/field-photo-prep-team/contractor-invite.html`

That URL must be allowed by hosted Supabase Auth redirect configuration. The current connector does not expose hosted Auth URL configuration, so this remains a genuine provider reality gate until the first controlled invite is attempted.

## Failure behavior

- Seat full → no Auth invitation attempt.
- Existing Auth email/live invitation → reject; no duplicate identity.
- Known-safe Auth failure with no created identity → `FAILED`, seat released.
- Ambiguous Auth outcome → `PROBLEM`, seat stays reserved, no blind resend.
- Metadata/finalization uncertainty → account remains non-assignable.
- Unaccepted invite → remains pending and consumes a seat in this early slice.
- Password/activation failure → account remains non-assignable; evidence is preserved.

## Applied migrations

- `20260915021612_add_contractor_invite_foundation.sql`
- `20260915022720_index_contractor_invitation_creator.sql`

Live Team development migration history matches those repository versions.

## Deployed trusted runtime

Supabase Edge Function:

- slug: `admin-invite-contractor`
- JWT verification: enabled
- server-only environment credentials; no secret values committed
- CORS restricted to the Team GitHub Pages origin

## Verification evidence completed before reality gate

Database/authorization checks:

- current organization reports **1 of 2** Contractor seats used, 1 available — PASS;
- first reservation fits the second seat — PASS;
- third-seat reservation is rejected before Auth work — PASS;
- duplicate live invitation rejected — PASS;
- Contractor caller cannot reserve invitation — PASS;
- authenticated browser role has no direct SELECT/INSERT/UPDATE on invitation table — PASS;
- authenticated browser role cannot execute trusted finalize function — PASS;
- transaction-only test proved `SENT` invitation makes a Contractor non-assignable — PASS;
- work-order trigger rejected assignment to that pending identity — PASS;
- activation to `ACCEPTED` restored assignability — PASS;
- all fixture mutations rolled back; no fake Auth user or invitation persisted — PASS.

Dashboard/Edge safeguards:

- Admin invite controls reuse the existing governed Admin tab session rather than adding a second auth-storage path;
- browser sends only name/email plus normal Admin bearer token;
- invite acceptance stores no Auth token in browser storage;
- Edge Function validates Admin caller server-side and contains no committed elevated credential value;
- dashboard CI gates contractor-invite markers and secret/session rules.

Advisor results after DDL:

- introduced unindexed `created_by` foreign key was fixed by migration `20260915022720`;
- remaining performance notices are informational unused-index notices, expected before this new path receives normal traffic;
- security advisor reports `contractor_invitations` has RLS with no policies. This is intentional: browser roles have no direct table privileges and all browser access is through narrow RPCs;
- pre-existing Auth leaked-password-protection warning is unchanged by this slice.

## Distribution/provider reality boundary

The repository’s GitHub Pages workflow deploys `dashboard/**` from **`main` only**. Therefore the real Admin invite controls and invite-acceptance page cannot be exercised on the Galaxy S22 from this isolated PR branch without adding throwaway preview infrastructure.

We will not add preview infrastructure merely to satisfy the test. The merge/deploy is the smallest real distribution boundary for this feature.

After exact-final-head CI and explicit Level-3 operator approval, merge/deploy may be used as the staged reality gate. If the first invite proves the Supabase redirect URL is not allowlisted, stop there, add only that provider configuration, and retry deliberately.

## Post-merge Galaxy S22 reality gate

1. Admin refreshes the real dashboard.
2. Contractor section shows `1 of 2` seats used/reserved.
3. Admin enters a disposable/test email they control and a test name.
4. Invitation email arrives.
5. Test account opens invitation and chooses its own password.
6. Account reports ready; Admin taps Refresh Contractors.
7. Seat summary becomes `2 of 2`, and new Contractor appears in assignee dropdown.
8. Reassign `TEST-0003-DASHBOARD` from original Contractor to test Contractor.
9. Original Contractor app refresh proves WO disappears and assignment receipt reset is visible from Admin.
10. Reassign back to original Contractor.
11. Original Contractor app receives it again and receipt confirms.
12. If practical, use the same test Contractor for one real `IN_PROGRESS` approve/decline handoff.

## Merge gate

Because this is Level 3, the exact final branch head must pass Admin + Android CI and the final diff must be reviewed before the operator is asked for explicit pre-merge approval.

That approval authorizes merge/deploy specifically to cross the main-only GitHub Pages distribution boundary and perform the controlled provider/device reality gate above. If reality contradicts the implementation, stop and correct only the proven issue before continuing.
