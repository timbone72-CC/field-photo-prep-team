# Field Work Hub — Phase 3B Implementation Plan — 2026-10-02

Status: **PROPOSED — AWAITING OPERATOR PLAN APPROVAL; NO RUNTIME IMPLEMENTATION**

Plan ID: `phase-3b-offline-field-actions-plan`.

## Classification and authoritative line

- Goal: let a contractor durably Start Work and Finish Field Work offline, then reconcile those exact actions safely when the app next connects.
- Current change: **Level 1**, documentation only. Eventual implementation: **Level 3**, because Room, server authorization, persisted queue state and reconciliation change.
- Authoritative planning branch: `docs/phase-3b-offline-field-actions-plan`. This document and the Phase 3 section of `docs/ROADMAP.md` form the proposed plan. The planning PR records its exact head and approval state.
- Baseline and documentation rollback: main `e348257220a00bc207c1099c8308b6701aeaedf8`, the merged Phase 3A PR #17. Preflight found no open PRs or competing Phase 3B line.
- Rule packs: AGENTS, GOVERNANCE, PROJECT_PROFILE, RULE_INDEX, CHANGE_CONTROL_CONTRACT, TESTING_CONTRACT, INTEGRATION_CONTRACT and PHASE_STAGING_DOCTRINE, plus the relevant roadmap identity, assignment, cancellation and Phase 3 sections.
- Current affected surfaces: this plan and the roadmap. No live schema, Auth, APK, dashboard, runtime code or field data changes.
- Eventual external surface: the existing FWH Team Supabase project `vyocaujuwrivoqynvitm` and an update of the existing internal Android app. No new backend or technical identity.
- Protected boundaries: FPP remains untouched; retain organization/role/assignment authority, exact owner/WO/run identity, receipt-after-durable-save, encrypted session handling, contractor isolation, consent rules and all unresolved offline evidence.
- Current verification boundary: document/contract review and diff check. Runtime, database and physical evidence remain pending and cannot be inferred from this plan.

Approval of this plan permits the documented implementation, not its Level 3 merge. After planning is integrated, create one runtime branch/PR from the then-current governed main and one implementation record; carry this plan's identity and decisions forward. Do not start an overlapping runtime line while this planning line is unresolved.

## Baseline problem and scope

Phase 3A has a verified owner-scoped Room v1 cache and session recovery. Its refresh currently deletes and replaces all cached rows for an owner/org, including the second refresh after receipt acknowledgement. There is no local action queue or Android Start/Finish control. Existing WO-only Start/Complete RPCs use server execution time and have no immutable action UUID or run argument; they cannot safely replay an offline event by themselves.

Phase 3B adds a narrow two-action queue, foreground sync, and the reconciliation needed to protect it. Phase 3C retains responsibility for WorkManager and persistent background execution. There is no polling, camera, photo validation, upload, Drive integration, Reopen/uncancel flow, new role, generic event system, or broad Admin conflict-resolution screen in this scope.

## Contractor workflow

1. Sign in and use **Refresh Assignments** online to download the current assignment/run and its assignment-instance identity. Existing v1 cached rows remain readable after upgrade; Start/Finish requires one successful identity refresh if that row lacks the new identity.
2. On an eligible downloaded `ASSIGNED` run, tap **Start Work** online or offline. Commit the action to Room before showing **Started — waiting to sync**. On an already server-started run, show the accepted state and allow Finish without creating a redundant Start.
3. Tap **Finish Field Work** after a durable local Start or an accepted server Start. Commit COMPLETE before showing **Field complete — waiting to sync**. Before Phase 4, validate field state only; no photo counts or camera prerequisites.
4. With connectivity, app open/sign-in, an online action, or **Refresh Assignments** runs the same foreground sync owner. START precedes COMPLETE for each run. Accepted results update Room and display confirmed field state. Pending local completion is always distinct from server completion.
5. A reassignment, cancellation, stale run, or invalid action becomes **Needs review**, with a plain explanation and retained local progress. For example: “This work was reassigned. Your offline progress is saved. Contact Admin.” A problem on one WO does not stop unrelated eligible WOs.

Disable repeated action taps once the matching durable action exists. A failed local write leaves the prior state and shows that the action could not be saved. A conflicted run cannot queue more progress. When this device has unresolved field actions for a run, **Approve** handoff is blocked with an instruction to sync or contact Admin; **Decline** remains available under existing server authorization. This narrow pending-action guard is proposed here rather than waiting for Phase 4's additional photo guard.

## Local identity, storage and state

Use one Room v1-to-v2 additive, non-destructive migration. Keep the database filename, package and signer. Preserve every v1 cached row and its owner/org/WO/run fields; export and test the new schema. Do not use destructive fallback, clear app data, or reinstall to recover a migration problem.

Add an action table owned by local persistence. Each action stores:

- immutable action UUID, owner user UUID, organization UUID, WO UUID, run UUID and assignment-instance UUID;
- START or COMPLETE, the original UTC device event timestamp, durable creation time and a transactionally allocated ordering sequence;
- PENDING, SYNCING, ACCEPTED or CONFLICT;
- last attempt/result, a bounded error/reason code, and the server's canonical state/event timestamps when accepted.

Action identity and event time never change during retry. Repeated taps cannot create a second action of the same kind for the same owner/WO/run/assignment instance. The ordering sequence, not the wall clock, orders local actions; backwards clock movement is detected rather than used to reorder or rewrite them.

Cache the assignment-instance UUID in the downloaded snapshot. The authorized server projection selects the current open history row, or the matching current FIELD_COMPLETE history closure, following Phase 3A's receipt-history rule. An A → B → A reassignment creates a new instance even if the same user returns; it must not authorize old offline actions.

Derive display state from the server snapshot plus durable actions/reconciliation state. Keep server status/times separate from local pending status/times. All reads, inserts, attempts, results and reconciliation use captured owner/org/WO/run identity, never whichever card is selected later. Sign Out locks access and retains the queue. A different user/org cannot view or send it. An old session callback cannot update the new account's UI; any durable result is written only to the original owner/action.

SYNCING interrupted by process death becomes eligible for retry with the same UUID/payload after reconstruction. The server ledger makes that retry safe even if the first request committed. Retain accepted action evidence in Phase 3B; do not add purge/discard controls.

## Narrow server acceptance contract

Introduce a run-bound, action-UUID-based acceptance RPC and a small server acceptance ledger for START/COMPLETE only. Mirror additive DDL and exact applied migration order. The client may read authorized results but cannot directly insert/update/delete ledger rows or broad WO/run state. No elevated key ships to Android.

The request binds action UUID, WO, run, assignment instance, kind and original event time. Derive actor and organization from verified server-controlled identity; never authorize from supplied actor values or editable user metadata. Validate Contractor role, current membership/authority, exact WO/run relationship, current run, exact assignment instance and legal state transition. Existing Admin workflow and Phase 2 entry points remain compatible; they cannot bypass this RPC's stricter offline acceptance checks.

Serialize the action and competing assignment/cancellation/consent mutations on the same WO row. During implementation, enumerate existing mutation RPCs and add the necessary transaction row locks to their owning functions so state is validated under that lock. In one transaction, validate, apply the transition, preserve the Phase 3A WO/run/history projections, and record the immutable acceptance result. An exception rolls back both transition and ledger entry.

Idempotency rules:

- Same UUID and identical immutable payload: return its authorized recorded result without applying another transition, including after a later assignment change. Current account authorization still gates access; do not expose another actor/org's ledger entry.
- Same UUID with different immutable payload or actor: reject; never replace the ledger row.
- A different UUID for an already-recorded eligible transition on the same current assignment may return an explicit already-applied result with canonical server times, without overwriting them. Store the request's claimed time separately; never present it as the canonical accepted event time.
- New START is legal on ASSIGNED; START on the same already-IN_PROGRESS assignment may converge as already applied. New START on FIELD_COMPLETE conflicts. COMPLETE requires IN_PROGRESS or an already-completed matching current assignment. Cancelled, different-instance, different-run and unauthorized actions cannot force progress.

For a newly applied transition, started_at/field_completed_at uses the original event timestamp, not reconnect time. Record server acceptance time separately. Proposed timestamp policy: reject malformed times, events more than five minutes in the server's future, events earlier than the assignment-instance start minus five minutes, and COMPLETE earlier than the canonical Start. There is no arbitrary maximum offline duration. Clock rejection preserves the original action and becomes Needs review; it does not silently substitute now. These are sanity checks on a device-reported time, not proof that the device clock was accurate.

Do not auto-correct, delete or rebind a rejected action. A successful exact-UUID replay returns recorded canonical times rather than re-evaluating the event against today's clock. Invalid/unauthorized requests receive bounded structured failure reasons without leaking other users' data.

## Foreground sync and refresh reconciliation

Use one coordinator for automatic foreground attempts and **Refresh Assignments**. Prevent simultaneous drains for the same owner. Re-read the durable action immediately before sending it. Confirm the active session matches its owner/org; invalid sessions require the same account to reauthenticate, retaining evidence.

Drain eligible actions in deterministic order, independently per WO/run. Do not send COMPLETE until its START is accepted or a verified server Start already exists. A transport timeout, offline failure or lost response leaves the same action retryable. A structured assignment/run/state/timestamp denial becomes a protected conflict and blocks dependent actions for that run. Authentication failure pauses sending and retains evidence; known revocation blocks new actions while preserving readable protected records. Do not spin or repeatedly send a known rejected action. No background scheduling or backoff framework is introduced here.

After attempts, fetch an authorized complete assignment snapshot and reconcile it transactionally. Receipt is still acknowledged only after the assignment is durably saved. Both the first save and the post-receipt refresh preserve action rows and overlays. A failed/partial fetch is not proof of removal; leave cached work intact.

| Successful refresh result | Required local result |
| --- | --- |
| Same current assignment/run | Update mutable snapshot; preserve actions and pending display. Incorporate verified canonical acceptance without creating a new action. |
| Assignment absent; no local Start/action evidence | Remove from active cache, scoped to the authenticated owner/org. |
| Assignment absent/changed, cancelled, or replaced run; local evidence exists | Retain cached details and actions, show Needs review, block further progress. Never retarget to the new owner/run. |
| Accepted action result arrives before a stale snapshot | Keep the durable accepted result; do not roll progress backwards. Use server state markers and acceptance evidence to detect contradictions; refetch or protect as Needs review rather than guessing. |
| Authentication/session changes during refresh | Retain the old owner's evidence and prevent cross-account display or submission. |

For missing work, use an authorized narrow reconciliation lookup where needed to distinguish a cancellation from reassignment. If RLS no longer permits that information, use a truthful generic message that assignment cannot be confirmed; do not broaden contractor access to other assignees' work or details.

Admin remains the authority for assignment resolution. Reassigning back creates a new assignment instance and does not automatically accept or retarget an older action. A future explicit evidence-resolution operation would require its own governed plan. Until then the protected conflict remains visible. Cancellation has no generic restore: a deliberate new dispatch is a new WO, and old actions stay bound to their old WO/run.

## Implementation ownership and safe batch

| Owner | Intended change |
| --- | --- |
| TeamDatabase, CachedWorkOrder/DAO, RoomAssignmentStore | Additive migration, action persistence, assignment identity, owner-scoped transactional reconciliation; replace destructive refresh semantics. |
| AssignmentRepository and a single action/sync repository | Durable action creation, queue drain, result recording, receipt-preserving refresh. |
| SupabaseApi and server migrations | Authorized assignment identity/probe; narrow acceptance RPC/ledger; serialization and grants/RLS. |
| MainActivity and existing session guard | Exact Start/Finish controls, pending/conflict rendering, handoff guard, account-safe callbacks. UI does not own persistence or authorization. |
| Existing Admin RPC owners | Only lock/validation changes necessary for the action-versus-assignment/cancellation race. No Admin UI redesign. |

Build the largest coherent approved batch through server acceptance, Room migration, queue, reconciliation and UI. Keep one runtime impact record containing exact heads, migration/live parity, fixtures, focused results, final CI, rollback and device gate. Before changing deployed state, reconcile the actual FWH schema/grants and existing mutation functions against authoritative source; a mismatch stops that affected path.

## Verification and staging

Focused automated proof must cover:

- Room v1-to-v2 preservation and reconstruction; two owners/orgs; pending actions survive restart and Sign Out; missing assignment identity cannot create an unbound action.
- Write failure and repeat taps; START-before-COMPLETE; backward/future clock cases; immutable payload on timeout/retry; interrupted SYNCING recovery.
- Both refresh passes preserve evidence; complete versus failed/partial snapshots; untouched eviction; stale accepted snapshots; reassignment, cancellation and A → B → A conflicts; one blocked WO does not block another.
- Controlled real PostgreSQL authorization context (or real JWT/RLS): allowed actor, wrong role/org/user, stale run/instance, direct-table denial, payload mutation, exact-UUID replay, competing reassignment/cancel lock outcomes and ledger/state atomicity.
- Original event time versus acceptance time; already-applied canonical results; old Phase 2 RPC compatibility; preserved run/history/receipt projections.
- Session switching during action/sync callbacks and the pending-action Approve blocker.

Safe disposable fixtures only; roll back SQL fixtures and avoid sequence/account changes where possible. Mirror each applied migration exactly, inspect grants/RLS and run Supabase advisors after DDL. Record any pre-existing warning separately. Run the final complete Android/Admin automated suite once on the exact runtime head after focused tests pass; do not claim physical proof from mocks or controlled SQL.

Then freeze one APK with exact runtime SHA, CI and artifact hash/package/signer, live parity, rollback and PASS/BLOCKED/FAIL criteria. The smallest straight-line phone gate is:

1. Update the existing installation; Refresh Assignments online for at least two disposable WOs and verify receipt/current identity.
2. Airplane mode on, Wi-Fi off. Start and Finish one WO offline; start the second. Confirm the distinct waiting-to-sync labels.
3. Use **Settings → Apps → Field Work Hub Internal → Force stop**, reopen offline, and confirm the same progress remains.
4. While the second WO remains offline, make one authorized disposable reassignment or cancellation in Admin.
5. Restore connectivity; open the app or tap **Refresh Assignments**. First WO converges START then COMPLETE exactly once with original tap times; second WO retains progress as Needs review. Confirm backend acceptance identities/times without repair.
6. Sign Out with the unresolved evidence, sign in as the existing second Contractor, verify isolation, then return to the original owner and confirm its conflict remains. Repeat Refresh Assignments to prove no duplicate effects.

Use exact visible labels, guide the operator one step at a time, and record each observation once. This extends the passed Phase 3A gate; it does not repeat that whole gate. Block if prerequisites cannot be established safely. Fail if evidence disappears, authority/identity is bypassed, pending is reported as accepted, an action is duplicated/retimed, or migration needs a data wipe.

## Rollback and completion gate

Documentation rollback is the narrow doc commit reversal to the baseline. Runtime rollback must preserve the new Room schema/action rows and server ledger. An old Room v1 APK cannot simply open a v2 database: do not downgrade, uninstall or clear data. Stage a forward-compatible recovery build from the known-good baseline behavior with v2 reading/preservation and action submission disabled if required; retain pending/conflict evidence. Keep additive server tables and acceptance records; disable a faulty narrow RPC by a mirrored forward migration if needed, rather than dropping data. Establish and verify those concrete recovery steps before enabling the runtime candidate.

Phase 3B is complete only when focused and exact-head complete automation, actual migration/grant/advisor parity, the single physical gate, data-preserving rollback readiness, explicit Level 3 merge approval and actual integration agree. Until then record PASS/BLOCKED/FAIL and the exact next gate. Phase 3C/background sync and full Phase 3 remain incomplete after a Phase 3B pass.

Current handoff: plan recorded for review; no Phase 3B implementation, live changes or runtime test claims. Next gate is explicit approval of this proposed plan, then its integration before runtime work begins.
