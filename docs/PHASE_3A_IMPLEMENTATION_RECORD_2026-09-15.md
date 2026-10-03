# Phase 3A Implementation Record — Run Identity + Room Cache

Date: 2026-09-15

Status: **PHASE 3A GATES PASSED — LEVEL 3 — OPERATOR MERGE APPROVAL RECORDED**

Branch: `feat/phase-3a-run-room-foundation`

Original implementation base: `0c657182443d09f86c7e23872458f457016468c2`

Current main / runtime rollback point: `778dfc5f67e47157f6b154d5476b26ae427bad55`

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

Receipt synchronization selects the current open assignment or its `FIELD_COMPLETE` closure. Old reassignment records cannot compete when timestamps are equal, including when a contractor returns to the same run.

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

The governed migration action applied `20261002221935_phase_3a_run_foundation` and the narrow advisor repair `20261002222320_phase_3a_index_and_rls_advisor_repair` to FWH on 2026-10-02. Both exact applied SQL statements are mirrored under `supabase/migrations/`; the draft is removed. Versions come from live migration history, not invented timestamps.

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

Session writes and invalidation share `SessionOperationGuard`. A refresh that returns after Sign Out cannot save credentials or reopen the work list. Old successes/errors cannot update a newer login. Activity destruction invalidates callbacks without clearing the session needed for restart. Queued refresh/reassignment operations read the latest encrypted refresh token, and a successful rotation updates the in-memory session even when the following work-order request fails.

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

Supabase gate completed on 2026-10-02 (evidence below):

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

1. install the final Phase 3A APK over the existing FWH internal app on the supported test Android phone;
2. sign in online and refresh disposable assignments;
3. verify receipt only after durable download;
4. kill/restart app while online and verify cached reconstruction + refresh;
5. disable network, kill/restart, verify downloaded work opens from Room;
6. verify explicit Sign Out returns to login without deleting Room evidence;
7. verify another signed-in user cannot see the prior user's cache when a second test contractor becomes available;
8. restore network and verify clean refresh convergence.

Two existing test Contractor accounts are now available. Use those accounts for the owner-isolation check; do not create another invitation or replace either account. Automated Room owner isolation remains distinct from physical evidence.

Phase 3B Start/Finish offline actions are not part of this gate.

## Rollback

### Repository

Revert only the merged Phase 3A change, preserving current main `778dfc5f67e47157f6b154d5476b26ae427bad55` and its onboarding, automatic Admin updates, redirect cutover and FWH branding. The original pre-reconciliation base is historical evidence, not the current rollback target.

### Android

Room v1 is additive. Do not delete the database merely to roll back a failed UI build. If an older build cannot open the newer app data, uninstall/reinstall is acceptable only on disposable internal-test devices with no Phase 3B/Photo evidence. Once real unresolved evidence exists, destructive rollback is forbidden.

### Supabase

Before live application, capture the exact pre-migration schema evidence. If the migration itself fails, stop and do not stack repair migrations blindly. If a post-application defect is found, preserve run/history rows and use a narrow forward repair migration; do not drop history tables or erase assignment evidence as a routine rollback.


## Resume checkpoint — 2026-10-02

- Goal / scope key: reconcile the existing `phase-3a-run-room-foundation` draft with completed FWH main and complete its automated gate.
- Level: **Level 3**; authoritative line remains `feat/phase-3a-run-room-foundation`, draft PR #17. No replacement branch/PR.
- Operator authorization: the operator replied **Next** to updating this draft and completing automated checks. This authorizes the present reconciliation; it is not pre-merge approval or authorization for Phase 3B/3C.
- Required packs: AGENTS.md, GOVERNANCE.md, PROJECT_PROFILE.md, RULE_INDEX.md, CHANGE_CONTROL_CONTRACT.md, TESTING_CONTRACT.md, INTEGRATION_CONTRACT.md, docs/PHASE_STAGING_DOCTRINE.md, approved roadmap Phase 3, this record.
- Observed starting draft: `cb703406d0765e5cd7f0583fe94e45c2ee8b32e0`.
- Reconciled main / rollback: `778dfc5f67e47157f6b154d5476b26ae427bad55` (PRs #20, #27, #28 and #29 are included).
- Affected surfaces: existing Phase 3A Android/Room/session draft, Android CI, roadmap status and this record. Server SQL draft remains unchanged.
- Protected behavior: durable save precedes receipt; exact owner/org/WO/run cache binding; Sign Out locks without deleting Room; existing contractor consent and dispatch; FWH package/signer/data; original FPP separation.
- Main overlap: the sole textual conflict was the Android artifact name. CI retains Phase 3A JVM tests and Room schema export alongside the current FWH label/icon/package/signer checks; artifacts are named for FWH Phase 3A.
- Narrow session repair: delayed refresh could previously repersist credentials and reopen the list after Sign Out. Guarded credential writes and UI callbacks now invalidate that operation. Queued refreshes use the latest durable rotated token rather than a stale UI snapshot.
- Focused verification: 15 Admin dashboard regression tests passed locally. Three JVM session-operation regressions cover delayed refresh after Sign Out, old-account failure after a new login, and Activity destruction preserving restart credentials. Full Room/encrypted-session/Android build and identity proof belongs to PR #17's exact-head CI.
- External state: read-only inspection of FWH project `vyocaujuwrivoqynvitm` on 2026-10-02 found no `work_order_runs`, no `work_order_assignments`, no `work_orders.current_run_id`, and no `photos.run_id`. Live migration history ends with `20260915104441_index_contractor_invitation_cancellation_audit`. No DDL, Auth settings, Edge Function, hosted dashboard, Drive, signer or FPP state was changed in this checkpoint.
- Automated gate: verify all required GitHub checks on the published PR head; exact result/SHA is recorded in PR #17's verification section. A failure blocks progression.
- Physical evidence: **PENDING**; do not install this migration-dependent candidate before the governed database gate passes.
- Merge: **NOT MERGED / APPROVAL PENDING**.
- Next exact gate after automated PASS: review/apply the staged Phase 3A migration through the governed migration action, mirror its returned version, verify Run-1/history/photo binding, timestamp preservation and real authorization/RPC behavior, then run advisors. After backend parity, stage one cache/restart/Sign Out/owner-isolation phone gate. Phase 3B/3C and phone automatic refresh are outside this checkpoint.


## Database-gate authorization / preflight — 2026-10-02

The operator replied **Next** to Phase 3A database migration and verification after the automated gate passed on `ee1e0c509115eac988028986c8974e7c8f2229cc`. This authorizes applying the reviewed additive migration to the existing FWH project `vyocaujuwrivoqynvitm`, verifying the affected boundaries and mirroring the actual applied version. PR #17 remains the sole Level-3 implementation line; merge approval and the physical gate remain pending.

Preflight confirms main remains `778dfc5f67e47157f6b154d5476b26ae427bad55`, the target is the separate healthy Team/FWH Postgres 17.6 project, and the run/history schema is absent. Baseline has 6 WOs, 5 assigned WOs and 0 photo rows. Capture schema/trigger/RPC/policy evidence plus business-data and timestamp checksums before DDL. The additive backfill locks the affected tables, snapshots existing business facts transaction-locally, and raises on changed data, broken Run-1 projection, photo binding or failure to restore the timestamp trigger.

The reviewed draft also resolves an assignment-instance ambiguity: identical timestamps from repeated reassignment must not let old reassignment records compete with the active assignment or its FIELD_COMPLETE closure for receipt synchronization. The staged controlled-context regression uses existing accepted test users, custom WO numbers and transaction/subtransaction rollback; it does not consume the business numbering sequence, change Auth accounts or alter existing WOs/photos.

Before/after advisors distinguish baseline notices from new findings. Existing baseline notices are the intentionally inaccessible contractor-invitation table (INFO), disabled leaked-password protection (WARN), and unused-index INFO notices. No Auth-setting change is included in this database gate. Rollback remains transaction abort on failed backfill; after a successful application, preserve additive history and use a proven narrow forward repair if needed, never delete history to revert the APK.


## Database gate result — 2026-10-02 — PASS

- Target: FWH project `vyocaujuwrivoqynvitm`; original FPP unchanged.
- Actual live migrations: `20261002221935_phase_3a_run_foundation` and `20261002222320_phase_3a_index_and_rls_advisor_repair`. The foundation mirror was compared byte-for-byte with the stored migration statement; the repair mirrors its stored SQL. No migration is reapplied to the live project.
- Backfill: 6 WOs → 6 Run-1 rows; 5 known assignments → 5 assignment-history rows; 0 photos remain 0. All 6 current-run pointers, ownership, organization, status, receipt/start/completion and created/updated timestamps match their existing WO projection. The original business-row checksum (which includes all original timestamps) remains `4b7f14d479184e5a86b12e4182c84a9a`; photo checksum remains `d41d8cd98f00b204e9800998ecf8427e`. The timestamp trigger is enabled. The same business checksum was verified after both fixture runs.
- Controlled database authorization/RPC gate: **PASS**, then **PASS** after advisor repair. `tests/supabase/phase_3a_database_gate.sql` uses actual PostgreSQL authenticated/anonymous roles, RLS and controlled `app_metadata` claims with existing accepted test users. This is the contract's equivalent controlled project context, not a signed-JWT/client-network or physical-device claim.
- Covered: Admin creation and invalid assignee rejection; wrong-role Admin action; tenant/owner read isolation; no broad direct writes; idempotent receipt/start/completion; ASSIGNED reassignment and receipt reset; previous-owner denial; in-progress decline/approve consent preserving run/start identity; A→B→A history and late receipt on the completed current assignment; allowed exact photo metadata identity and denied mismatched run/WO/owner; wrong-org/wrong-role receipt and anonymous history denial; immediate validation of the deferred WO/run constraint.
- Fixtures use custom numbers and a caught rollback sentinel inside an outer rollback transaction. All temporary organizations/WOs/runs/history/photo metadata were removed; no business sequence consumption, existing WO/photo mutations, Auth-account changes, files or uploads.
- Initial post-DDL advisors identified 2 uncovered composite FKs and 3 claim-evaluation performance warnings. The narrow forward repair adds covering indexes, replaces the superseded single-column photo index, and wraps the JWT function itself in a scalar SELECT while preserving access semantics. Required gate reran successfully.
- Final advisors: no new security warning; performance has only 16 unused-index INFO notices, expected for lightly used/new indexes. Existing invitation-table INFO and [disabled leaked-password protection WARN](https://supabase.com/docs/guides/auth/password-security#password-strength-and-leaked-password-protection) remain baseline, outside this gate. No Auth setting is changed. [Unused-index guidance](https://supabase.com/docs/guides/database/database-linter?lint=0005_unused_index).
- Repository next gate: publish these mirrors, fixture regression and records on the existing PR #17; final Android/Admin/governance CI must pass on that exact head. Record the final SHA/results in PR metadata without another runtime edit.
- Physical result: **PENDING**. After exact-head CI, next is the single Phase 3A phone cache/restart/Sign Out/owner-isolation gate described above. No Phase 3B/3C, phone auto-refresh, camera or Drive behavior is authorized.
- Merge: **DRAFT / NOT MERGED / explicit operator approval still pending**. Runtime rollback remains current main `778dfc5f67e47157f6b154d5476b26ae427bad55`; preserve applied database history and use a narrow forward repair if a demonstrated defect arises.


## Phone gate result — 2026-10-02 America/Chicago — PASS

Goal/scope: record the completed Phase 3A device gate on the existing authoritative branch/PR #17. This checkpoint changes documentation/PR metadata only (Level 1); the parent implementation remains Level 3. No runtime, migration, account, deployment, signer or FPP change.

Tested runtime: `3191dd0ec29ec8e0f29e7d748ed8b8e54bdd6131`, tree `2b0fe78e7c86590e36c1ed24fd3ad7da7d5f2b41`. APK: `Field-Work-Hub-0.3-Phase3A-3191dd0.apk`, SHA-256 `3d2bd5e2c01538e3e3b02ba7280671100e105e1687de345478339836085aa7f4`, from Android CI run `37072465869`, artifact `11255371162` (archive digest checked against GitHub). FWH package `com.inandout.fieldphotoprep.team.internal`; unchanged signer SHA-256 `1bbff192f97a8a24c6f812d77df6847eb9759b3afb3c4b210d9e6c251f4eecfe`. Android full tests/build/schema/identity/signer, Admin run `37072465864`, and governance passed on that runtime. Subsequent checkpoint changes are documentation only; no replacement APK or repeat device gate is required without a runtime change.

Operator-reported physical observations on the same Android phone:

- Update installation/open: **PASS**.
- Online Contractor sign-in/download with at least two test work orders visible: **PASS**.
- Online force-stop/reopen: same WOs returned without another sign-in: **PASS**.
- Airplane mode with Wi-Fi off, force-stop/reopen, downloaded list and WO details accessible without sign-in: **PASS**.
- Offline Sign Out followed by force-stop/reopen: sign-in screen, no ordinary access to WOs: **PASS**. Physical UI evidence proves the lock; unchanged Room rows/session-only clearing is also covered by automated tests, not claimed from direct on-phone database inspection.
- Restore internet; second existing Contractor account on the same phone: first account's assignments absent: **PASS**. No new invitation/account was created.
- Sign Out of the second account, return to original account online: original WOs returned; operator confirmed **Refresh Assignments** is visible and works: **PASS**. Earlier instruction shortened the label to “Refresh”, causing confusion; there is no missing-button defect. Sign-in itself reloads the authorized snapshot.

Read-only FWH receipt check after the phone gate (2026-10-03 UTC): 5 current non-cancelled assigned WOs, 4 with non-null accepted receipt, and all 5 receipt projections consistent across WO/run/current-or-completed assignment. An assigned WO need not be received until downloaded by its owner. Durable-save-before-acknowledgement ordering is proved by the focused repository tests; aggregate provider inspection does not claim per-tap timing evidence.

Evidence is accepted once from the operator's confirmations; no physical test is inferred from CI. Test WO data is retained as the existing disposable assignment baseline, not deleted during this record-only checkpoint. Original FPP, Drive, Auth configuration and accounts are unchanged. Full Phase 3 offline Start/Finish/reconciliation/WorkManager behavior remains unimplemented and unproven.

Next exact gate: final PR/CI review and explicit operator approval before merging PR #17. Current main/runtime rollback remains `778dfc5f67e47157f6b154d5476b26ae427bad55`; preserve additive database history and local evidence. Merge is **NOT APPROVED / NOT MERGED**. No Phase 3B/3C or phone automatic-refresh implementation is authorized by the passing phone gate.


## Operator merge approval / integration handoff — 2026-10-02 22:33 America/Chicago

The operator replied **approved** to the explicit request to merge PR #17 after the database, phone and final automated gates passed. This is the required Level-3 pre-merge approval, distinct from earlier implementation authorization. Reviewed handoff head: `55b341eb6c226a6cb6c3a0eecf588f1f85851ff3`; full Android/Admin/governance checks passed and there are no review threads or change requests. This final approval checkpoint changes only documentation and the project profile; all runtime files remain identical to the phone-tested `3191dd0ec29ec8e0f29e7d748ed8b8e54bdd6131`.

[PR #17](https://github.com/timbone72-CC/field-work-hub/pull/17) is the authoritative merge-outcome record, including its final head, result and merge SHA. Merge only the approved authoritative branch into unchanged main `778dfc5f67e47157f6b154d5476b26ae427bad55`, with an expected-head check and successful final checks; do not bypass branch protection or rewrite main. Retain the existing tested APK and accept the recorded phone evidence without another installation or repeat gate.

Phase 3A run identity, durable Room downloads and session/cache isolation have passed their completion gates. Full Phase 3 remains incomplete. After successful integration, the next scope is a governed Phase 3B implementation-plan review for offline Start/Finish, run-bound idempotent acceptance and preservation/reconciliation before runtime work. This merge approval does not authorize Phase 3B/3C, WorkManager, automatic phone refresh, camera or Drive delivery. Original FPP remains untouched. Retain existing disposable WOs and protected local evidence; no cleanup or Auth changes accompany this merge. Runtime rollback remains `778dfc5f67e47157f6b154d5476b26ae427bad55` with additive backend history preserved.
