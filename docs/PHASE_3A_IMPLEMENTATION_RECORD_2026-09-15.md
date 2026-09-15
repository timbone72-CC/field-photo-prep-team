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
4. add the immutable `photos.run_id` schema binding required once run identity exists, without adding photo capture/upload behavior;
5. add Android Room v1 storage for downloaded work;
6. make an online refresh transactionally replace the current server snapshot in Room;
7. render normal contractor work from Room after durable save;
8. acknowledge assignment receipt only after the downloaded snapshot is committed to Room;
9. preserve downloaded work across app/process restart;
10. persist reusable Supabase session material encrypted with Android Keystore so restart can attempt session refresh without storing plaintext credentials;
11. when network/session refresh is unavailable, allow the previously authenticated cache owner to read that owner's downloaded work only;
12. explicit Sign Out clears reusable local session credentials and locks ordinary cache access without deleting downloaded work.

Out of scope:

- Phase 3B offline Start/Finish queue;
- Phase 3C persistent action sync / WorkManager;
- camera/photo capture, preparation, counters, or upload behavior beyond the required server run-ID binding;
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

### `work_orders` current-run projection

The current Phase 2 `work_orders` row remains the transactional projection used by existing Admin/Contractor RPCs.

Phase 3A adds:

- `current_run_id` — immutable run UUID pointer for the currently dispatched run;
- `current_run_sequence` — display/projection sequence, initially `1`.

Every existing work order is backfilled into Run 1. The pointer backfill temporarily disables only the existing `work_orders_set_updated_at` trigger so adding schema identity does not falsify historical business `updated_at` timestamps. The trigger is immediately re-enabled inside the same migration.

The work-order current-run pointer is constrained to a run belonging to the same work order. New work orders reserve the run UUID before insert constraints are checked and create the matching Run-1 row in the same transaction.

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

Receipt synchronization updates the most recent matching assignment row, including an already-closed `FIELD_COMPLETE` assignment when receipt is acknowledged after field completion.

### Projection synchronization

Use private database triggers so existing, already-tested Phase 2 RPCs remain the only business-action API:

- new work-order insert creates Run 1 and its first assignment record;
- work-order state/timestamps update the current run;
- assignment receipt updates the matching assignment-history row;
- assignee change closes the old assignment and opens the new assignment;
- completed/cancelled state closes the open assignment;
- authenticated clients receive `SELECT` only on the new history tables; no direct client writes are added.

### Photo run identity binding

Once run identity exists, every photo must identify both its permanent WO and the exact field run.

Phase 3A therefore:

- adds `photos.run_id`;
- backfills any pre-existing photo row from its WO current run;
- makes `run_id` non-null;
- constrains `(run_id, work_order_id)` to the same `work_order_runs` row;
- requires future contractor photo inserts to target the WO's current run.

This is identity/schema protection only. Phase 3A does not add camera, photo preparation, photo counts, queue state transitions, or remote delivery behavior.

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

The staged SQL remains under `supabase/drafts/` until it is applied through the governed Supabase migration action. After application, the exact generated migration version is mirrored under `supabase/migrations/`; no hand-invented migration timestamp is used.

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
- reserved synchronized Admin-updates JSON slot (empty list until the server model supplies updates);
- due date;
- requirement snapshot JSON (empty object until the server model supplies requirements);
- server field state/timestamps;
- receipt timestamp;
- pending reassignment fields already returned by Phase 2;
- server `updated_at` snapshot marker;
- last successful local sync time.

Normal work-list rendering reads from Room, not the transient HTTP response.

Room schema version 1 is exported and committed so later Room migrations can be tested from an exact historical schema.

### Refresh transaction

For Phase 3A, where no local field-action/photo overlays exist yet:

1. fetch server-authorized rows;
2. verify organization/run identity and contractor assignment invariants;
3. map to Room entities for the exact authenticated user/org;
4. replace that user's server snapshot in one Room transaction;
5. only after the transaction succeeds, acknowledge eligible assignment receipts;
6. refetch server truth when a receipt changed;
7. transactionally store the receipt-confirmed snapshot;
8. render from Room.

If the first durable save fails, receipt is not acknowledged. If the receipt succeeds but the second local save fails, the first durable snapshot remains; the next refresh can converge to the already-confirmed server receipt without losing the downloaded assignment.

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

## Automated verification

Implemented focused coverage includes:

- Room database/schema generation;
- multiple cached assignments survive database close/reopen under Robolectric;
- user A query cannot return user B cache rows;
- replacing user A's server snapshot does not erase user B's cache;
- snapshot replacement uses one Room transaction;
- failed durable save cannot call receipt acknowledgement;
- receipt acknowledgement is observed only after the first successful durable save;
- encrypted session store round-trips without plaintext token/email persistence;
- malformed stored session fails closed and removes the reusable credential;
- explicit session clear removes reusable credentials without owning/deleting Room data;
- Android CI runs the Phase 3A JVM test suite before APK assembly;
- generated Room v1 schema is exported as CI evidence and committed.

Still required at the Supabase gate:

- migration applied through the governed migration action;
- exact applied migration mirrored into repository history;
- Run-1 backfill count equals work-order count;
- current-run pointer integrity;
- work-order business `updated_at` timestamps preserved by backfill;
- assignment-history baseline integrity;
- photo run binding integrity;
- RLS/grants verified;
- existing Phase 2 RPC behavior rechecked;
- Supabase advisors run after DDL.

Before merge, complete Android/Admin CI must pass on the exact final runtime head.

## Physical gate after all automated/provider-independent work

1. install final Phase 3A APK on the S22;
2. sign in online and refresh disposable assignments;
3. verify receipt only after durable download;
4. kill/restart app while online and verify cached reconstruction + refresh;
5. disable network, kill/restart, verify downloaded work opens from Room;
6. verify explicit Sign Out returns to login without deleting Room evidence;
7. verify another signed-in user cannot see the prior user's cache when a second test contractor becomes available;
8. restore network and verify clean refresh convergence.

The second-contractor isolation check may remain externally blocked until another valid test Contractor exists; automated Room owner isolation already protects the local data boundary in the meantime.

Phase 3B Start/Finish offline actions are not part of this gate.

## Rollback

### Repository

Revert the Phase 3A PR to base `0c657182443d09f86c7e23872458f457016468c2`.

### Android

Room v1 is additive. Do not delete the database merely to roll back a failed UI build. If an older build cannot open the newer app data, uninstall/reinstall is acceptable only on disposable internal-test devices with no Phase 3B/Photo evidence. Once real unresolved evidence exists, destructive rollback is forbidden.

### Supabase

Before live application, capture the exact pre-migration schema evidence. If the migration itself fails, stop and do not stack repair migrations blindly. If a post-application defect is found, preserve run/history rows and use a narrow forward repair migration; do not drop history tables or erase assignment evidence as a routine rollback.
