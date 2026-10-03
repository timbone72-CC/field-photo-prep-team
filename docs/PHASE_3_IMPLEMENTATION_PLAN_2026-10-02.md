# Field Work Hub — Phase 3 Implementation Plan — 2026-10-02

Status: **APPROVED PLAN — 3A MERGED; 3B/3C IMPLEMENTED AND GATES PASSED; MERGE PENDING**

Plan ID: `phase-3-implementation-plan`.

Current execution checkpoint (2026-10-03): PR #32 implemented the unchanged remaining 3B/3C scope. Backend, exact-runtime automation and the combined physical gate passed on installed runtime `87e57d4fc476800be96f6730e6631c23f1729536`, including actual background acceptance before app reopening and protected conflict/account isolation. See [PHASE_3_IMPLEMENTATION_RECORD_2026-10-03.md](PHASE_3_IMPLEMENTATION_RECORD_2026-10-03.md). Final documentation checks, explicit Level 3 merge approval and integration remain pending. The planning-baseline descriptions below are historical; they do not override the current implementation record or require repeating accepted evidence.

## Classification and authoritative line

- Goal: complete the whole Phase 3 workflow: durable owner-scoped downloads, offline Start/Finish, protected reconciliation and persistent eligible action sync when connectivity permits.
- Current change: **Level 1**, documentation only. Eventual implementation: **Level 3**, because Room, server authorization, persisted queue state and reconciliation change.
- Authoritative planning line: existing [PR #30](https://github.com/timbone72-CC/field-work-hub/pull/30), branch `docs/phase-3b-offline-field-actions-plan`. Its historical branch name is retained to preserve one line. Its scope key is expanded to `phase-3-implementation-plan`; no competing planning PR is created. This parent plan replaces the section-only file and governs all 3A/3B/3C sections through the roadmap.
- Baseline and documentation rollback: main `0b825040133764887e954e5b6cf1c19dfd01c7e5`, containing merged Phase 3A PR #17 and whole-phase rules PR #31. Preflight found only PR #30 open. Bring these main rules into the existing planning branch; preserve its prior history.
- Rule packs: AGENTS, GOVERNANCE, PROJECT_PROFILE, RULE_INDEX, CHANGE_CONTROL_CONTRACT, TESTING_CONTRACT, INTEGRATION_CONTRACT and PHASE_STAGING_DOCTRINE, plus the relevant roadmap identity, assignment, cancellation and Phase 3 sections.
- Current affected surfaces: this plan and the roadmap. No live schema, Auth, APK, dashboard, runtime code or field data changes.
- Eventual external surface: the existing FWH Team Supabase project `vyocaujuwrivoqynvitm` and an update of the existing internal Android app. No new backend or technical identity.
- Protected boundaries: FPP remains untouched; retain organization/role/assignment authority, exact owner/WO/run identity, receipt-after-durable-save, encrypted session handling, contractor isolation, consent rules and all unresolved offline evidence.
- Current verification boundary: document/contract review and diff check. Runtime, database and physical evidence remain pending and cannot be inferred from this plan.

## Approval and retained evidence

The roadmap records parent product/phase approval on **2026-09-14**, including 3A downloads, 3B offline actions and 3C WorkManager/reconciliation. The operator approved the detailed 3B decisions at **2026-10-02 22:55:40 America/Chicago**, reviewing proposal head `aaa24d309a9cc01292da10a10449265f53bb167d`. That includes the five-minute timestamp tolerance, pending-action handoff blocker and assignment-instance replay protection. The later stop paused execution; it did not revoke that approval. The operator then requested the rule correction and continued consolidation at 23:15:36.

This revision consolidates those recorded approvals and fills 3C scheduling/recovery/test details within its existing scope. It does not infer 3C authorization from the 3B-only approval or claim the operator separately approved this exact document revision. No new product decision is introduced: WorkManager, backoff, durable rereads, authorization rejection and conflict preservation were already required by the approved roadmap. A material change discovered during implementation still requires a parent-phase amendment; unchanged decisions do not need another approval.

### 3A — completed foundation

PR #17 merged as `e348257220a00bc207c1099c8308b6701aeaedf8`. Run/assignment history, the owner-scoped Room v1 cache, encrypted session restoration, receipt-after-save and account isolation are implemented. Exact migration/grant/advisor/preservation and CI evidence is in `PHASE_3A_IMPLEMENTATION_RECORD_2026-09-15.md` and the merged PR. The phone-tested runtime is `3191dd0ec29ec8e0f29e7d748ed8b8e54bdd6131`; the APK hash is `3d2bd5e2c01538e3e3b02ba7280671100e105e1687de345478339836085aa7f4`.

The recorded phone gate passed online restart, offline downloaded work after force-stop/reopen, Sign Out lock, second-account isolation and return with **Refresh Assignments**. Accept that evidence once. Do not restart 3A, reinstall its APK, or rerun its entire gate for this planning correction. New v1-to-v2/action/worker behavior gets the targeted proof below.

### Whole-phase execution order

| Section | Dependency and work | Evidence boundary |
| --- | --- | --- |
| 3A | Merged foundation; reuse its code, identities and accepted evidence. | Already passed; retained. |
| 3B | Run-bound acceptance, additive Room migration, durable queue, foreground sync and protected reconciliation. | Focused backend/Room/action tests establish queue correctness before enabling scheduling. |
| 3C | Schedule that same correct queue through WorkManager, using the same coordinator/session/server authority. | Focused worker/scheduling tests, then one exact-head complete suite and one combined remaining-phase phone gate. |

After this documentation is integrated, create one Level 3 runtime branch/PR from governed main and one implementation record for **3B and 3C together**. Implement in dependency order and test the queue before adding its worker; do not pause for an intermediate letter-only approval or phone gate. Build all safely provable remaining work before staging the combined physical gate. Separate explicit Level 3 pre-merge approval remains mandatory.

## Baseline problem and scope

Phase 3A has a verified owner-scoped Room v1 cache and session recovery. Its refresh currently deletes and replaces all cached rows for an owner/org, including the second refresh after receipt acknowledgement. There is no local action queue or Android Start/Finish control. Existing WO-only Start/Complete RPCs use server execution time and have no immutable action UUID or run argument; they cannot safely replay an offline event by themselves.

The remaining Phase 3 scope adds a narrow two-action queue, foreground sync, protected reconciliation and WorkManager for persistent action sync. There is no periodic assignment polling, automatic phone assignment refresh feature, camera, photo validation, upload, Drive integration, Reopen/uncancel flow, new role, generic event system, or broad Admin conflict-resolution screen. Worker reconciliation after an action drain uses the same authorized snapshot rules; it is not a new assignment polling service.

## 3B — contractor workflow and durable actions

1. Sign in and use **Refresh Assignments** online to download the current assignment/run and its assignment-instance identity. Existing v1 cached rows remain readable after upgrade; Start/Finish requires one successful identity refresh if that row lacks the new identity.
2. On an eligible downloaded `ASSIGNED` run, tap **Start Work** online or offline. Commit the action to Room before showing **Started — waiting to sync**. On an already server-started run, show the accepted state and allow Finish without creating a redundant Start.
3. Tap **Finish Field Work** after a durable local Start or an accepted server Start. Commit COMPLETE before showing **Field complete — waiting to sync**. Before Phase 4, validate field state only; no photo counts or camera prerequisites.
4. With connectivity, app open/sign-in, an online action, or **Refresh Assignments** runs the same foreground sync owner. START precedes COMPLETE for each run. Accepted results update Room and display confirmed field state. Pending local completion is always distinct from server completion.
5. A reassignment, cancellation, stale run, or invalid action becomes **Needs review**, with a plain explanation and retained local progress. For example: “This work was reassigned. Your offline progress is saved. Contact Admin.” A problem on one WO does not stop unrelated eligible WOs.

Disable repeated action taps once the matching durable action exists. A failed local write leaves the prior state and shows that the action could not be saved. A conflicted run cannot queue more progress. When this device has unresolved field actions for a run, **Approve** handoff is blocked with an instruction to sync or contact Admin; **Decline** remains available under existing server authorization. This narrow pending-action guard was approved with the 3B proposal; Phase 4 later adds its photo guard.

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

SYNCING interrupted by process death becomes eligible for retry with the same UUID/payload after reconstruction. The server ledger makes that retry safe even if the first request committed. Retain accepted action evidence through Phase 3; do not add purge/discard controls.

## Narrow server acceptance contract

Introduce a run-bound, action-UUID-based acceptance RPC and a small server acceptance ledger for START/COMPLETE only. Mirror additive DDL and exact applied migration order. The client may read authorized results but cannot directly insert/update/delete ledger rows or broad WO/run state. No elevated key ships to Android.

The request binds action UUID, WO, run, assignment instance, kind and original event time. Derive actor and organization from verified server-controlled identity; never authorize from supplied actor values or editable user metadata. Validate Contractor role, current membership/authority, exact WO/run relationship, current run, exact assignment instance and legal state transition. Existing Admin workflow and Phase 2 entry points remain compatible; they cannot bypass this RPC's stricter offline acceptance checks.

Serialize the action and competing assignment/cancellation/consent mutations on the same WO row. During implementation, enumerate existing mutation RPCs and add the necessary transaction row locks to their owning functions so state is validated under that lock. In one transaction, validate, apply the transition, preserve the Phase 3A WO/run/history projections, and record the immutable acceptance result. An exception rolls back both transition and ledger entry.

Idempotency rules:

- Same UUID and identical immutable payload: return its authorized recorded result without applying another transition, including after a later assignment change. Current account authorization still gates access; do not expose another actor/org's ledger entry.
- Same UUID with different immutable payload or actor: reject; never replace the ledger row.
- A different UUID for an already-recorded eligible transition on the same current assignment may return an explicit already-applied result with canonical server times, without overwriting them. Store the request's claimed time separately; never present it as the canonical accepted event time.
- New START is legal on ASSIGNED; START on the same already-IN_PROGRESS assignment may converge as already applied. New START on FIELD_COMPLETE conflicts. COMPLETE requires IN_PROGRESS or an already-completed matching current assignment. Cancelled, different-instance, different-run and unauthorized actions cannot force progress.

For a newly applied transition, started_at/field_completed_at uses the original event timestamp, not reconnect time. Record server acceptance time separately. Approved timestamp policy: reject malformed times, events more than five minutes in the server's future, events earlier than the assignment-instance start minus five minutes, and COMPLETE earlier than the canonical Start. There is no arbitrary maximum offline duration. Clock rejection preserves the original action and becomes Needs review; it does not silently substitute now. These are sanity checks on a device-reported time, not proof that the device clock was accurate.

Do not auto-correct, delete or rebind a rejected action. A successful exact-UUID replay returns recorded canonical times rather than re-evaluating the event against today's clock. Invalid/unauthorized requests receive bounded structured failure reasons without leaking other users' data.

## Foreground sync and refresh reconciliation

Use one coordinator for automatic foreground attempts and **Refresh Assignments**. Prevent simultaneous drains for the same owner. Re-read the durable action immediately before sending it. Confirm the active session matches its owner/org; invalid sessions require the same account to reauthenticate, retaining evidence.

Drain eligible actions in deterministic order, independently per WO/run. Do not send COMPLETE until its START is accepted or a verified server Start already exists. A transport timeout, offline failure or lost response leaves the same action retryable. A structured assignment/run/state/timestamp denial becomes a protected conflict and blocks dependent actions for that run. Authentication failure pauses sending and retains evidence; known revocation blocks new actions while preserving readable protected records. Do not spin or repeatedly send a known rejected action. 3B establishes these rules before the 3C worker is attached; both entry points then use the same coordinator.

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

## 3C — persistent action sync

### Scheduling and queue ownership

After focused queue correctness tests pass, add a pinned compatible WorkManager runtime/test dependency. A scheduler requests ordinary one-time, network-connected work for eligible durable actions. No periodic worker, expedited/foreground service, battery-exemption settings flow or additional sync button is introduced. Use one stable unique work name per owner/org, with identity-only input; never serialize tokens, WO snapshots or action payloads into WorkManager input/output.

On each committed action, and on app initialization/sign-in/Refresh Assignments, reconcile pending eligible actions with scheduled work. Room is the queue of record. A crash after the Room commit but before enqueue retains the action; the next app initialization recreates its scheduling. A scheduling exception leaves pending visible and preserves foreground sync; record a bounded reason and retry scheduling on the next authorized trigger.

Use a unique one-time drain chain with `APPEND_OR_REPLACE` and coalesce simultaneous triggers in the scheduler. A new action committed while a drain is finishing must have a successor; a KEEP-only approach that can strand that action is insufficient. Every worker drains the current eligible Room rows rather than trusting work-input selection. Empty successor drains exit safely. WorkManager success/cancellation is not a field-action acceptance result and never removes an action.

Foreground and worker paths acquire the same owner-scoped coordinator lock and transactionally claim the next durable action. Only the matching action claim may finalize that original owner's local attempt; a changed session generation forbids further sends and updates to the new account's UI/credentials. A verified response to an already-sent request may still be recorded against its exact original owner/action. Interrupted claims are recovered with unchanged UUID/payload. Build this into the v2 action schema before the candidate is installed, rather than introducing a later destructive schema change. Duplicate requests remain harmless at the server ledger. Re-read pending rows before finishing a drain so concurrent new actions cannot be lost.

### Credentials and account changes

Load credentials only through the existing encrypted session owner. Introduce one narrowly shared session coordinator for foreground/worker credential restoration, refresh-token rotation and Sign Out/account-generation invalidation; the worker does not build an independent Auth implementation. Serialize refresh and credential writes so an older refresh callback cannot replace a newer login or resurrect a signed-out session.

Before each network submission, check that the active durable session/generation still matches the action owner/org, refresh an expired token through the authorized session path, and re-read the action. Missing/unreadable credentials, account mismatch or refresh rejection stop that owner's worker without deleting evidence or looping on login failures. Signing back into the same account re-enqueues its eligible actions; another account never resumes them. Sign Out invalidates the session and cancels its scheduled work without touching Room evidence. Cancellation is cooperative: a request already sent may commit, and its exact-UUID result/replay must be preserved for the original owner; Sign Out cannot undo an authorized server commit.

### Results, retry and interruption

| Worker observation | Required outcome |
| --- | --- |
| Eligible actions accepted or already applied | Persist canonical result in Room; continue that run in START-before-COMPLETE order. |
| No eligible actions, signed out, owner mismatch or known Auth rejection | Finish the work request without retry; retain pending/conflict evidence. Reauthentication or a new authorized trigger can schedule it later. |
| Retry-safe offline/timeout/rate-limit/transient server failure | Retain the immutable pending action, continue unrelated eligible WOs where possible, then return retry for remaining retry-safe work. Respect any server retry delay. |
| Structured assignment/run/state/timestamp rejection | Mark that run Needs review, retain dependent actions, and continue unrelated WOs; do not retry the rejected run indefinitely. |
| Network constraint loss, worker stop or process death | Stop claiming/sending new work; retain or release interrupted claims safely. A later attempt re-reads Room and replays the same UUID if its remote result is unknown. |
| Invalid response or unexpected persistent protocol/local-storage failure | Preserve evidence and a bounded error; stop the affected path. Do not mark accepted or blindly retry a known deterministic defect. |

Configure exponential transport retry with the standard 30-second initial WorkManager backoff. Execution is deferred by Android constraints and scheduling, not guaranteed at an exact second. Foreground Refresh Assignments can still attempt eligible work immediately through the same coordinator. Retry identity and ordering never depend on work-request IDs or attempt count.

Normal backgrounding, process loss and reboot must retain eligible scheduled work and its Room evidence. An explicit Android **Force stop** suppresses background execution until the app is opened again; reopening recovers/re-enqueues pending work. The phone gate therefore tests force-stop persistence separately from ordinary background execution. Never claim instant background sync or require the operator to change battery settings to make the planned gate pass; record an actual scheduler restriction as BLOCKED.

Technical references checked for this plan: Android Developers [work requests/constraints/backoff](https://developer.android.com/develop/background-work/background-tasks/persistent/getting-started/define-work), [unique work policies](https://developer.android.com/develop/background-work/background-tasks/persistent/how-to/manage-work), and AndroidX [force-stop recovery source](https://android.googlesource.com/platform/frameworks/support/+/f2e05c341382db64d127118a13451dcaa554b702/work/workmanager/src/main/java/androidx/work/impl/utils/ForceStopRunnable.java). These constrain implementation; they do not constitute device evidence.

## Implementation ownership and safe batch

| Owner | Intended change |
| --- | --- |
| TeamDatabase, CachedWorkOrder/DAO, RoomAssignmentStore | Additive migration, action persistence, assignment identity, owner-scoped transactional reconciliation; replace destructive refresh semantics. |
| AssignmentRepository and a single action/sync repository | Durable action creation, queue drain, result recording, receipt-preserving refresh. |
| SupabaseApi and server migrations | Authorized assignment identity/probe; narrow acceptance RPC/ledger; serialization and grants/RLS. |
| SecureSessionStore and shared session coordinator | Encrypted credentials, serialized token refresh, durable session generation and Sign Out invalidation; no second authentication owner. |
| Action scheduler/worker and shared sync coordinator | One-time scheduling, network constraint/backoff, owner checks, cooperative stop and durable queue recovery; no new business authority. |
| MainActivity and existing session guard | Exact Start/Finish controls, pending/conflict rendering, handoff guard, account-safe callbacks. UI does not own persistence or authorization. |
| Existing Admin RPC owners | Only lock/validation changes necessary for the action-versus-assignment/cancellation race. No Admin UI redesign. |

Build the largest coherent approved batch through server acceptance, Room migration, queue, reconciliation, session coordination, UI and persistent action scheduling. Keep one runtime impact record containing exact heads, migration/live parity, fixtures, focused results, final CI, rollback and device gate. Before changing deployed state, reconcile the actual FWH schema/grants and existing mutation functions against authoritative source; a mismatch stops that affected path.

## Verification and staging

Focused automated proof must cover:

- Room v1-to-v2 preservation and reconstruction; two owners/orgs; pending actions survive restart and Sign Out; missing assignment identity cannot create an unbound action.
- Write failure and repeat taps; START-before-COMPLETE; backward/future clock cases; immutable payload on timeout/retry; interrupted SYNCING recovery.
- Both refresh passes preserve evidence; complete versus failed/partial snapshots; untouched eviction; stale accepted snapshots; reassignment, cancellation and A → B → A conflicts; one blocked WO does not block another.
- Controlled real PostgreSQL authorization context (or real JWT/RLS): allowed actor, wrong role/org/user, stale run/instance, direct-table denial, payload mutation, exact-UUID replay, competing reassignment/cancel lock outcomes and ledger/state atomicity.
- Original event time versus acceptance time; already-applied canonical results; old Phase 2 RPC compatibility; preserved run/history/receipt projections.
- Session switching during action/sync callbacks and the pending-action Approve blocker.
- WorkManager network constraints, unique scheduling, enqueue failure/commit-before-enqueue recovery, arrival during drain shutdown, no eligible-row cleanup, and empty successors.
- Foreground-versus-worker claims, worker cancellation/constraint loss, process reconstruction, transport backoff versus terminal conflicts, and one rejected WO with another accepted WO.
- Session refresh rotation races, Sign Out during refresh/submission, account-switch generation checks, missing credentials, owner reauthentication and protection against stale credential resurrection.

Safe disposable fixtures only; roll back SQL fixtures and avoid sequence/account changes where possible. Mirror each applied migration exactly, inspect grants/RLS and run Supabase advisors after DDL. Record any pre-existing warning separately. Run the final complete Android/Admin automated suite once on the exact runtime head after focused tests pass; do not claim physical proof from mocks or controlled SQL.

After both 3B and 3C pass focused tests and the exact-head complete suite, freeze one APK with runtime SHA, CI and artifact hash/package/signer, live parity, rollback and PASS/BLOCKED/FAIL criteria. No 3B-only phone installation/gate is planned. This one remaining-phase session proves actual Android upgrade/restart/offline behavior and ordinary background scheduling, which mocks cannot establish. It gates the remaining Phase 3 merge/completion and the following phase. The laptop is used for disposable Admin race setup and read-only server observations, not an unrelated additional test cycle. The smallest straight-line gate is:

1. Update the existing installation; Refresh Assignments online for at least two disposable WOs and verify receipt/current identity.
2. Airplane mode on, Wi-Fi off. Start and Finish one WO offline; start the second. Confirm the distinct waiting-to-sync labels.
3. Use **Settings → Apps → Field Work Hub Internal → Force stop**, reopen offline, and confirm the same progress remains.
4. While the second WO remains offline, make one authorized disposable reassignment or cancellation in Admin.
5. With the app reopened offline, press Home to leave it normally in the background. Restore connectivity without opening it or tapping Refresh Assignments. Observe read-only backend results from the laptop: the first WO converges START then COMPLETE once with original tap times through the worker; the second WO cannot force progress. Observe for up to ten minutes as a diagnostic window, not a promised Android deadline. If the worker is not observed running, record BLOCKED and investigate scheduling; do not call foreground recovery a background pass.
6. Reopen the app and confirm accepted first-WO state and preserved second-WO Needs review. Tap **Refresh Assignments** and confirm convergence without duplicate effects.
7. Sign Out with the unresolved evidence, sign in as the existing second Contractor, verify isolation, then return to the original owner and confirm its conflict remains. Pending work is never submitted under the other account. Restart/reboot scheduling and interruption races also have focused automated coverage; add another physical check only if a concrete remaining uncertainty requires it.

Use exact visible labels, guide the operator one step at a time, and record each observation once. This combined gate extends the passed Phase 3A gate; it does not repeat that whole gate. Block if prerequisites cannot be established safely. Fail if evidence disappears, authority/identity is bypassed, pending is reported as accepted, an action is duplicated/retimed, or migration needs a data wipe.

## Rollback and completion gate

Documentation rollback is the narrow doc commit reversal to the baseline. Runtime rollback must preserve the new Room schema/action rows and server ledger. An old Room v1 APK cannot simply open a v2 database: do not downgrade, uninstall or clear data. Stage a forward-compatible recovery build from the known-good baseline behavior with v2 reading/preservation and action submission/scheduling disabled if required; retain pending/conflict evidence. Keep additive server tables and acceptance records; disable a faulty narrow RPC by a mirrored forward migration if needed, rather than dropping data. Cancel only scheduled drains when pausing sync; retain all Room actions and server acceptance rows. Establish and verify those concrete recovery steps before enabling the runtime candidate.

The whole Phase 3 is complete only when retained 3A evidence, focused 3B/3C tests, exact-head complete automation, actual migration/grant/advisor parity, the combined physical gate including observed background action sync, data-preserving rollback readiness, explicit Level 3 merge approval and actual integration agree. A queue-only pass cannot mark the worker or the parent phase complete. Record PASS/BLOCKED/FAIL and the exact next evidence gate. The current 3B/3C backend/automated/physical gate results are PASS in the linked implementation record; documentation CI is not substituted for that runtime/physical evidence. Explicit Level 3 merge approval and integration remain pending.

Current handoff: the parent plan was integrated through PR #30 and its remaining 3B/3C implementation now owns PR #32. The planned backend, queue, worker, migration/recovery and combined physical gates have passed. Complete final documentation/PR checks and obtain the separate explicit Level 3 merge approval before integration. Retain the installed tested APK and protected conflict evidence; do not restart planning, rebuild the runtime or repeat accepted phone gates for this status update.
