# Contractor Invitation Cancellation — 2026-09-15

## Classification

**Level 3 — destructive Supabase Auth cleanup and seat/invitation authorization.**

Approved user problem: an Admin can mistype an invitation email, but the first contractor-invite slice has no way to cancel the pending invitation or reclaim the reserved seat.

Known-good rollback baseline: `f45de3d356306f60738ca154eea5333f6a94d030`.

## Approved behavior

A Team Admin may cancel only a **pending, unaccepted Contractor invitation** in the same organization.

For an invitation that has never been accepted and whose Auth identity has never signed in and has no Team work-order reference, cancellation:

1. verifies the caller is the same-organization `ADMIN`;
2. verifies the invitation is still pending (`RESERVED`, `SENT`, or `PROBLEM`);
3. verifies any linked Auth user is unconfirmed/unaccepted, has never signed in, and is not referenced by a work order;
4. transitions the invitation through seat-reserving `CANCELLING` while trusted cleanup runs;
5. deletes that disposable unused Auth identity through trusted server-side Auth Admin authority when one exists;
6. marks the invitation `CANCELLED`, clears its active Auth-user link, and records cancellation time + cancelling Admin;
7. releases the reserved Contractor seat only after cancellation is proven complete;
8. leaves a durable cancellation record rather than deleting invitation history.

Cancellation must fail closed if the identity has been accepted/confirmed, has signed in, is assigned/pending-assigned to work, or otherwise cannot be proven unused. Used contractor identities follow deactivation/history-preservation rules instead of deletion.

## Current typo fixture authorized for cleanup

The operator explicitly authorized destructive cleanup of the unused typo invitation created during the internal smoke test. Cleanup was limited to the server-verified invitation/identity that was unconfirmed, never signed in, and had no work-order reference. The mistyped email itself is not committed to the public repository.

Cleanup result:

- invitation preserved as `CANCELLED`;
- active `auth_user_id` cleared;
- prior disposable Auth UUID retained only as non-FK cancellation evidence;
- Auth identity no longer exists;
- no work-order reference exists;
- seat state returned to 1 active Contractor, 0 pending invitations, limit 2.

## Implementation boundary

- Add `CANCELLED` and seat-reserving `CANCELLING` invitation states plus cancellation audit fields by forward migration.
- Add a narrow Admin-readable pending-invitation list RPC.
- Add trusted cancellation preparation/finalization actions that enforce same-org Admin authority and unused-identity preconditions.
- Extend the trusted `admin-invite-contractor` Edge Function with a cancel operation so reusable Auth deletion stays server-side.
- Extend the existing Admin contractor panel with pending invitations and a `Cancel Invitation` control.
- Do not add resend, expiry automation, deactivation/reactivation, contractor hard deletion, billing, or broader account management in this slice.

## Authority and safety

- Supabase/Postgres owns invitation state, seat accounting, same-org authorization, and whether cancellation is eligible.
- Supabase Auth Admin API owns destructive deletion of the disposable Auth identity in the reusable runtime path.
- Browser requests cancellation but cannot delete Auth users or directly mutate invitation state.
- Service-role/secret credentials remain only in the trusted Edge Function.
- `CANCELLING` remains seat-reserving and non-assignable while deletion/finalization is in flight.
- Seat is not released until the server has either proven there is no Auth identity to delete or successfully deleted the eligible disposable identity and finalized cancellation.
- Ambiguous deletion/finalization outcome fails closed as `PROBLEM`/unresolved and continues reserving the seat until reconciled.

## Verification evidence

Focused checks completed:

- same-org Admin pending-invitation list works;
- pending reservation occupies the second seat;
- Admin begin-cancel transitions to `CANCELLING`;
- successful cancellation preserves durable `CANCELLED` evidence and releases the seat;
- Contractor caller is denied Admin pending-list and cancel actions;
- existing confirmed/used Contractor identity is rejected by the destructive cancellation path;
- browser roles retain no direct `SELECT`/`INSERT`/`UPDATE` privilege on `contractor_invitations`;
- browser roles cannot execute trusted cancellation finalization;
- current typo cleanup proves Auth row removed, invitation preserved as cancelled, no WO references, and seat returned to available;
- rollback fixtures left no persistent test rows.

A focused test initially found ambiguous PL/pgSQL qualification for `auth_user_id`; it was repaired by forward migration `20260915104300_fix_contractor_invite_cancel_target_qualification.sql`, then the focused cancellation suite passed.

Supabase DDL advisor follow-up:

- cancellation-audit foreign-key index findings were fixed by `20260915104441_index_contractor_invitation_cancellation_audit.sql`;
- remaining new index notices are expected `unused_index` informational findings on newly created paths;
- `contractor_invitations` intentionally has RLS enabled with no policies because browser roles have no direct table privileges and use narrow RPCs only;
- project-level leaked-password-protection warning predates this slice and is not changed here.

## Final gate

Before merge of the reusable runtime feature:

- Supabase migration history must match repository migration history;
- Admin + Android complete CI must pass once on the exact final branch head;
- final diff must contain no secrets, test-account PII, or unrelated changes;
- live Galaxy S22 dashboard must show the pending-invite/cancel workflow after publication for subsequent test invites;
- explicit operator Level-3 approval is required before merge. The operator's destructive-cleanup approval authorized cleanup of the identified unused typo fixture, but does not waive the final pre-merge gate for the reusable runtime feature.
