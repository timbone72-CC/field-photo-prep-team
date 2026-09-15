# Phase 3A Implementation Record — Run Identity + Room Cache

Date: 2026-09-15

Status: **IMPLEMENTATION IN PROGRESS — LEVEL 3 — DO NOT MERGE WITHOUT EXPLICIT OPERATOR APPROVAL**

Branch: `feat/phase-3a-run-room-foundation`

Base / rollback point: `0c657182443d09f86c7e23872458f457016468c2`

## Approved scope

Implement Phase 3A from `docs/ROADMAP.md` only:

1. introduce durable server run identity without breaking the Phase 2 work-order projection;
2. backfill every existing work order into Run 1;
3. preserve narrow assignment history and bind assignment receipt to the active assignment instance;
4. add Android Room v1 storage for downloaded work;
5. make an online refresh transactionally replace the current server snapshot in Room;
6. render normal contractor work from Room after durable save;
7. acknowledge assignment receipt only after the downloaded snapshot is committed to Room;
8. preserve downloaded work across app/process restart;
9. persist reusable Supabase session material encrypted with Android Keystore so restart can attempt session refresh without storing plaintext credentials;
10. when network/session refresh is unavailable, allow the previously authenticated cache owner to read that owner's downloaded work only;
11. explicit Sign Out clears reusable local session credentials and locks ordinary cache access without deleting downloaded work.

Out of scope:

- Phase 3B offline Start/Finish queue;
- Phase 3C persistent action sync / WorkManager;
- camera/photos/photo requirements;
- Google Drive delivery;
- new contractor roles or device-registration system;
- destructive cache discard/recovery UX;
- reopen workflow;
- production deployment/signing changes.

## Governing authority

- Supabase remains authoritative for authenticated identity, organization, current assignment, run state, and accepted server receipt.
- Room becomes authoritative only for whether a previously downloaded assignment/run is durably available on this device.
- A cached row is never evidence that the server still considers the assignment current.
- Local pending field actions are not introduced in Phase 3A.

## Server design

### `work_order_runs`

Create a narrow run table with:

- run UUID;
- work-order UUID;
- organization UUID;
- run sequence;
- current/final assignee UUID;
- field status;
- assignment receipt timestamp;
- started timestamp;
- field-completed timestamp;
- requirement snapshot JSON (empty object until Phase 4 supplies requirements);
- reopen reason nullable;
- created/updated/closed timestamps.

The current Phase 2 `work_orders` row remains the transactional projection used by existing Admin/Contractor RPCs. A `current_run_id` pointer is added to `work_orders` and every existing row is backfilled into Run 1.

### Assignment history

Create a narrow `work_order_assignments` table with:

- assignment UUID;
- run UUID;
- organization UUID;
- assigned user UUID;
- assignment start;
- assignment receipt;
- assignment end;
- end reason: `REASSIGNED`, `HANDOFF`, `CANCELLED`, `FIELD_COMPLETE`, or `ADMIN_ACTION`.

Existing pre-Phase-3 reassignment history cannot be reconstructed from the current projection. Backfill therefore records the current known assignment as the Run-1 baseline without inventing earlier history.

### Projection synchronization

Use private database triggers so existing, already-tested Phase 2 RPCs remain the only business-action API:

- new work-order insert creates Run 1 and its first assignment record;
- work-order state/timestamps update the current run;
- assignment receipt updates the open assignment-history row;
- assignee change closes the old assignment and opens the new assignment;
- completed/cancelled state closes the open assignment;
- authenticated clients receive `SELECT` only on the new history tables; no direct client writes are added.

The work-order current-run pointer is constrained to a run belonging to the same work order. The pointer is assigned before insert and the matching Run-1 row is created in the same transaction.

## RLS / grants

`work_order_runs`:

- RLS enabled;
- `anon` receives no access;
- `authenticated` receives `SELECT` only;
- Admin may select same-organization runs;
- Contractor may select runs whose current/final assignee is that user.

`work_order_assignments`:

- RLS enabled;
- `anon` receives no access;
- `authenticated` receives `SELECT` only;
- Admin may select same-organization assignment history;
- Contractor may select only assignment rows whose `assigned_user_id` is that user.

No authorization rule uses user-editable metadata. Organization and role remain sourced from server-controlled `app_metadata`.

## Supabase platform note

Current Supabase platform changes require explicit grants for newly exposed public tables. The migration therefore grants only the exact authenticated `SELECT` surface required by the Android client and leaves writes to trusted server-side paths/service role.

## Android Room design

Use stable Room 2.x rather than Room 3 because the Team client is currently Java-only and Room 3 requires KSP/coroutine-oriented APIs. Phase 3A uses Room `2.8.5` with Java annotation processing.

### Room v1 entity

Cache key:

`cache owner user UUID + work-order UUID + run UUID`

Cached fields:

- cache-owner user UUID;
- organization UUID;
- work-order UUID;
- run UUID and sequence;
- assigned user UUID;
- WO number/address/work type;
- base instructions;
- due date;
- requirement snapshot JSON;
- server field state/timestamps;
- receipt timestamp;
- pending reassignment fields already returned by Phase 2;
- server `updated_at` snapshot marker;
- last successful local sync time.

Normal work-list rendering reads from Room, not the transient HTTP response.

### Refresh transaction

For Phase 3A, where no local field-action/photo overlays exist yet:

1. fetch server-authorized rows;
2. map to Room entities for the exact authenticated user/org;
3. replace that user's server snapshot in one Room transaction;
4. only after the transaction succeeds, acknowledge eligible assignment receipts;
5. refetch server truth;
6. transactionally store the receipt-confirmed snapshot;
7. render from Room.

If the first durable save fails, receipt is not acknowledged.

Later Phase 3B/3C changes this replacement policy to preserve unresolved local overlays; Phase 3A must not pre-build or invent those overlays.

## Session / restart design

`SupabaseApi.AuthSession` is extended with organization UUID, refresh token, and expiry context.

Reusable session material is encrypted using an AES key generated in Android Keystore (`AES/GCM/NoPadding`) and only ciphertext/IV is stored in app-private preferences. No password is stored.

On app/process restart:

- decrypt the saved session identity;
- immediately load that exact user's cached rows from Room;
- attempt Supabase refresh when possible;
- if refresh succeeds, save rotated session material and run the normal server refresh;
- if transport is unavailable, keep the authenticated offline cache visible and label it as last-downloaded/offline state;
- if the server explicitly rejects the refresh token, clear reusable session credentials and lock ordinary cache access without deleting Room rows.

Explicit Sign Out clears the encrypted reusable session record and locks access; Room evidence remains.

## Automated verification planned

- Room database/schema generation succeeds;
- multiple cached assignments survive database close/reopen under Robolectric;
- user A query cannot return user B cache rows;
- snapshot replacement is transactional;
- failed durable save path cannot call receipt acknowledgement (repository-level test seam);
- cached data remains after Sign Out while ordinary access is locked by absence of session;
- encrypted session store round-trips without plaintext token persistence;
- malformed/undecryptable stored session fails closed;
- Supabase migration is reviewed against the live schema and existing migration chain before application;
- after migration application: verify backfill count, current-run pointer integrity, assignment-history baseline, RLS/grants, and existing Phase 2 RPC behavior;
- run Supabase advisors after DDL;
- run complete Android/Admin CI on the exact final head.

## Physical gate after all automated/provider-independent work

1. install final Phase 3A APK on the S22;
2. sign in online and refresh at least two disposable assignments;
3. verify receipt only after durable download;
4. kill/restart app while online and verify cached reconstruction + refresh;
5. disable network, kill/restart, verify downloaded work opens from Room;
6. verify another signed-in user cannot see the prior user's cache when a second test contractor becomes available;
7. restore network and verify clean refresh convergence.

Phase 3B Start/Finish offline actions are not part of this gate.

## Rollback

### Repository

Revert the Phase 3A PR to base `0c657182443d09f86c7e23872458f457016468c2`.

### Android

Room v1 is additive. Do not delete the database merely to roll back a failed UI build. If an older build cannot open the newer app data, uninstall/reinstall is acceptable only on disposable internal-test devices with no Phase 3B/Photo evidence. Once real unresolved evidence exists, destructive rollback is forbidden.

### Supabase

Before live application, capture the exact pre-migration schema evidence. If the migration itself fails, stop and do not stack repair migrations blindly. If a post-application defect is found, preserve run/history rows and use a narrow forward repair migration; do not drop history tables or erase assignment evidence as a routine rollback.
