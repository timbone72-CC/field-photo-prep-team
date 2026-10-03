# Phase 3 combined offline actions and background sync — implementation record

Scope key: `phase-3-offline-actions-sync`. Change level: **Level 3**.
Authoritative branch: `feat/phase-3-offline-actions-sync`; draft PR **#32**.
Baseline / recovery source: main `8a33ff7490716ea35520c8f97085cfee4f0883be`.

## Authority and scope

Implement the remaining Phase 3B/3C together under `PHASE_3_IMPLEMENTATION_PLAN_2026-10-02.md`. The original approved Phase 3 scope, detailed 3B approval on 2026-10-02 and operator **Next** on 2026-10-03 authorize this unchanged runtime batch. PR #30 consolidated the complete parent plan; PR #31 clarified governance. Existing Phase 3A phone/backend evidence is retained, not restarted. This is the single runtime line; preflight found no open overlapping PRs and main matched the baseline.

Affected surfaces: FWH narrow SQL acceptance/ledger and serialized existing mutations; additive Room v1→v2; durable START/COMPLETE actions and reconciliation; shared encrypted session coordination; MainActivity controls; constrained one-time WorkManager; focused SQL/JVM tests and Android CI. Required packs: AGENTS, GOVERNANCE, PROJECT_PROFILE, RULE_INDEX, CHANGE_CONTROL, TESTING, INTEGRATION, parent roadmap/plan and PHASE_STAGING_DOCTRINE.

Protected behavior: owner/org isolation, immutable WO/run/assignment/action identity and original device event time, preserved offline evidence, current server authority and consent/receipt projections. FPP, photos/camera/Drive, onboarding, unrelated dashboard features and accounts are outside scope.

External systems: only FWH Supabase `vyocaujuwrivoqynvitm` (migration mirror/parity, controlled rolled-back fixtures, advisors) and this GitHub runtime branch/CI. No customer data changes or new accounts are planned.

## Recovery

Room upgrade is additive and must not use destructive fallback. Once v2 is installed, recovery is a higher-version same-package/signer build retaining v2/action rows, with action submissions and scheduling disabled. No downgrade, uninstall, Clear data or evidence deletion. Prepare and verify the recovery variant before staging the candidate; preserve ledger/migrations rather than destructive SQL rollback.

## Verification and handoff

Status: **IN PROGRESS**. All five deployed mutation bodies/grants matched latest source. Narrow migration `phase_3_field_actions` applied as actual version **20261003122905**, exactly mirrored from the CLI-created draft (the temporary CLI filename is replaced with the server's recorded version). Server draft checkpoint: `ce9aafc841be9ea3ed90a6f5ac4b403cc7451408`. Work-order mutation owners are start_work, complete_field_work, acknowledge_assignment_received, admin_update_work_order (edit/reassign/request) and respond_reassignment (approve/decline). There is no deployed Contractor/Admin cancellation RPC or direct client UPDATE grant; cancellation fixtures use the controlled fixture owner, whose UPDATE also locks the WO row. No new cancellation UI/authority is introduced.

Controlled PostgreSQL gate **PASS**: current account/role/org and exact run/instance authority, table grants/RLS, malformed/future/backward times, stable UUID replay/payload collision, separate-UUID canonical convergence, A→B→A, replay after handoff, existing APIs and run/history/receipt projections. Fixtures fully rolled back; Auth accounts and sequence untouched. Six existing WOs and zero photos retained; pre/post WO hash **defd82ee10972d57ccc5478e44c42f23**, photo hash **d41d8cd98f00b204e9800998ecf8427e**, ledger zero rows after fixtures. The current database is PostgreSQL 17.6; relevant changelog/minor-upgrade notes checked, no custom operator/legacy encryption change used here.

Security advisor baseline remains leaked-password WARN and inaccessible invitation INFO. Performance advisor identified one new ledger JWT initplan warning; same-authority policy repair applied as **20261003123241**, exactly mirrored, and the new warning is gone. Only unused-index INFO remains. Local Gradle resolution initially blocked by the execution proxy; no Android test pass claimed from those failures. Queue/session/migration focused tests and runtime build are in progress.

Focused queue/storage/backend proof precedes worker integration; final exact-head Android/Admin suites follow once. Then stage one immutable candidate APK plus recovery APK, and run the single combined phone/laptop gate in the parent plan. Actual background acceptance must be observed without opening the phone app or tapping Refresh Assignments; force-stop persistence is a separate step.

Physical gate: **PENDING**. Final exact-head CI: **PENDING**. Live migration changes: **20261003122905 and 20261003123241 applied and mirrored**.
Level 3 merge approval: **PENDING**. Runtime merge: **NOT AUTHORIZED / NOT MERGED**.


Initial combined focused Android proof: **PASS** (queue, session rotation/generation races, real Room v1→v2 migration/reopen and WorkManager constraints/successor behavior). Local runtime tooling was reconstructed in scratch (Gradle 9.6.0, existing Android 36 build target, JDK 17); transient proxy/JRE/certificate failures were environment failures, not test passes. Additional focused fixes/coverage are being completed before final CI. WorkManager pinned to official stable **2.12.0**, compatible with this app's minSdk 26.

Hosted connector requests serialize on this execution path, so attempted concurrent hosted observations did **not** establish a two-session lock race; no concurrent proof is claimed from them. Both temporary race WOs/actions/history were cleaned through their exact fixture identities, leaving the original six WOs and zero ledger rows. Real lock races now have a disposable PostgreSQL 17.6 CI service with synthetic Auth actors and two independent connections, applying every authoritative migration in order. This does not alter hosted Auth or install a hosted test extension.


Focused verification after safeguards: **23 tests PASS** across OfflineActionTest, RoomMigrationTest, SessionCoordinatorTest, ActionSyncCoordinatorTest, ActionSchedulerTest and AssignmentSnapshotTest. A subsequent focused handoff/drain run **9 tests PASS** covers the shared handoff guard, pending/conflict blockade, serialized local action creation during approval, recovery pause and durable HTTP retry delay. This includes complete-snapshot proof via PostgREST exact Content-Range; missing/partial ranges cannot become cache-removal authority. Hosted gate repeated after the policy repair: **PASS**. Final Android/Admin/database/governance CI and candidate/recovery artifact identity are still pending on the upcoming runtime checkpoint.

The Android CI freezes candidate versionCode 4 and forward-recovery versionCode 5 from one exact source head, retaining package/signer and Room v2. It verifies sync true/false and exports each SHA-256 plus runtime head in immutable identity.json artifacts. Recovery has no action controls/submissions and preserves all queue rows. Remaining physical gate and Level 3 merge approval remain PENDING.


Development checkpoint **ef31e95a9323b94e2994c9d50d4f3457144bf881**: complete Android (run 37124491323), Admin (37124491344) and disposable database (37124491377) CI **PASS**. Database CI observed real lock waits in both orderings of START vs reassignment and START vs cancellation, with atomic authority/ledger outcomes. Candidate/recovery build identities passed. Final review then tightened UI callbacks and queued operations to their captured shared durable session generation; worker rejection/account switching cannot resurrect an older screen or clear another login. New focused callback regression plus final complete CI are required on the corrected runtime head before physical staging. The execution workspace restarted during this review; repository/source and CI proof survived on the authoritative PR. No work was restarted or new approval requested.


Artifact staging explicitly checks out the PR head in Android/Admin/database CI, and identity.json records `git rev-parse HEAD` rather than the pull-request event's synthetic merge SHA. This keeps the tested runtime, proposed head and downloadable candidate/recovery identity aligned. Physical staging remains blocked until all checks on that final head pass.

## Upgrade regression correction before phone installation — 2026-10-03

The operator stopped the stalled conversation and confirmed Done here at 08:17 America/Chicago. This session retains PR #32 and all previous passed evidence. Final review found that legacy Room v1 rows already IN_PROGRESS or FIELD_COMPLETE have server start times but no assignment-instance field. Their first v2 refresh falsely classified the confirmed current identity as an assignment change. Reconciliation now initializes the confirmed same-run identity for legacy rows only when no immutable local action exists. Known assignment-instance changes and queued evidence remain protected conflicts. Real v1 migration regressions cover assigned, started and completed work, separate owner preservation and pending Finish reconstruction.

Runtime 9106ff3 and its saved candidate/recovery are superseded before operator installation by this narrow fix. Physical staging is PAUSED until focused migration/queue proof, final corrected-head Android/Admin/database/governance CI and replacement APK identities pass. The phase scope, Room v2 schema, server migrations, package/signer and recovery rules are unchanged. Physical gate and explicit Level 3 merge approval remain PENDING.
