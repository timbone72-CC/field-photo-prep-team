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
4. deletes that disposable unused Auth identity through trusted server-side Auth Admin authority when one exists;
5. marks the invitation `CANCELLED`, clears its Auth-user link, and records cancellation time + cancelling Admin;
6. releases the reserved Contractor seat;
7. leaves a durable cancellation record rather than deleting invitation history.

Cancellation must fail closed if the identity has been accepted/confirmed, has signed in, is assigned/pending-assigned to work, or otherwise cannot be proven unused. Used contractor identities follow deactivation/history-preservation rules instead of deletion.

## Current typo fixture authorized for cleanup

The operator explicitly authorized destructive cleanup of the unused typo invitation created during the internal smoke test. Cleanup is limited to the server-verified invitation/identity that is unconfirmed, never signed in, and has no work-order reference. The mistyped email itself is not committed to the public repository.

## Implementation boundary

- Add `CANCELLED` invitation status and cancellation audit fields by forward migration.
- Add a narrow Admin-readable pending-invitation list RPC.
- Add trusted cancellation preparation/finalization actions that enforce same-org Admin authority and unused-identity preconditions.
- Extend the trusted `admin-invite-contractor` Edge Function with a cancel operation so Auth deletion stays server-side.
- Extend the existing Admin contractor panel with pending invitations and a `Cancel Invitation` control.
- Do not add resend, expiry automation, deactivation/reactivation, contractor hard deletion, billing, or broader account management in this slice.

## Authority and safety

- Supabase/Postgres owns invitation state, seat accounting, same-org authorization, and whether cancellation is eligible.
- Supabase Auth Admin API owns destructive deletion of the disposable Auth identity.
- Browser requests cancellation but cannot delete Auth users or directly mutate invitation state.
- Service-role/secret credentials remain only in the trusted Edge Function.
- Seat is not released until the server has either proven there is no Auth identity to delete or successfully deleted the eligible disposable identity and finalized cancellation.
- Ambiguous deletion/finalization outcome fails closed; invitation remains seat-reserving until reconciled.

## Verification

Focused checks:

- same-org Admin can list pending invitations;
- Contractor/wrong-role cannot list or cancel;
- pending invitation consumes a seat before cancellation and releases it after successful cancellation;
- accepted invitation cannot cancel;
- confirmed/signed-in Auth user cannot be deleted by this path;
- assigned/pending-assigned user cannot be deleted by this path;
- direct invitation-table mutation remains denied to browser roles;
- Edge Function still contains no committed service credential;
- cancellation leaves durable `CANCELLED` invitation evidence and no assignable Auth identity;
- typo fixture cleanup proves Auth row removed, invitation preserved as cancelled, no WO references, and seat returns to available.

Final gate:

- Supabase migration history matches repository migration history;
- security/performance advisors reviewed after DDL;
- Admin + Android complete CI pass once on exact final branch head;
- live Galaxy S22 dashboard shows the pending-invite/cancel workflow for subsequent test invites;
- explicit operator Level-3 approval is required before merge. The operator's current destructive-cleanup approval authorizes cleanup of the identified unused typo fixture, but does not waive the final pre-merge gate for the reusable runtime feature.
