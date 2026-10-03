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

## Corrected runtime frozen for the combined physical gate — 2026-10-03

Current status: **AUTOMATED PASS / PHONE GATE STAGED / PHYSICAL PENDING**. The earlier pending and paused checkpoints above are historical. PR #32 remains draft on `feat/phase-3-offline-actions-sync`; final tested runtime is **87e57d4fc476800be96f6730e6631c23f1729536**. Source correction 69bcfa4 preserves legacy started/completed rows during identity adoption; 87e57d4 records that correction. Replacement artifacts supersede 9106ff3. This staging record is a documentation-only follow-up; it does not change the frozen runtime.

Exact-runtime complete CI **PASS**: Android **37126042978**, Admin **37126042993**, disposable PostgreSQL authorization/atomicity/two-connection race gate **37126042975**, governance **37126041997**. Android focused regression and complete JVM suites, additive v1/v2 schema checks, package/network/signature checks and candidate/recovery identity checks all passed on the recorded head. No duplicate local complete suite is needed. The authoritative line retains applied mirrored migrations **20261003122905** and **20261003123241**, previous hosted parity/preservation/advisor evidence and accepted 3A phone evidence; no new live database change is made by staging.

| Verified artifact | Candidate | Forward recovery |
| --- | --- | --- |
| Filename | Field-Work-Hub-0.3-Phase3-candidate-87e57d4.apk | Field-Work-Hub-0.3-Phase3-recovery-87e57d4.apk |
| CI artifact ID | 11275671338 | 11275441588 |
| APK SHA-256 | f6b16a35d923f611b9aac26406fb4102c7672b10b1d52bf4ac0469b35190b9df | c6a9d65af01de7aca241fa4a01780ddddb50fb0d01d0450fcecaef606719938f |
| Version code / Room | 4 / 2 | 5 / 2 |
| Action submissions/scheduling | Enabled | Disabled |
| Retained artifact identity | libfile_f550406586888191ba8b78957a7715cc | libfile_b51477f988e08191bf949c63bb289e8c |

Both builds retain package `com.inandout.fieldphotoprep.team.internal`, label Field Work Hub Internal and signer SHA-256 **1bbff192f97a8a24c6f812d77df6847eb9759b3afb3c4b210d9e6c251f4eecfe**. Downloaded artifact ZIP digests matched GitHub (candidate **a9a146e44cabe06ffdd26c7068db07f8d341dbb6f9ee6770a77aed6a5268ded8**, recovery **4c7a1c1808005e4b0675cdf6eea0f6c1134e461213b29b5ee64662801e8826fb**); each APK hash matched its exact-head identity.json. Recovery is retained and ready before candidate installation. Source rollback reference remains main **8a33ff7490716ea35520c8f97085cfee4f0883be**; after v2 installation only forward same-signer recovery may be used, preserving action/cache rows. Never downgrade, uninstall or Clear data.

Next exact operator checkpoint: install candidate 87e57d4 over the existing Field Work Hub Internal app, open it and report Works or the exact error. Continue the linked parent plan's seven-step combined gate one visible step at a time: online disposable assignments/receipt; offline Start/Finish; force-stop/reopen persistence; authorized Admin reassignment of the second disposable WO; ordinary background reconnect and read-only server observation before app reopen; foreground confirmation/idempotency; account isolation with retained conflict. Existing Admin has no cancellation RPC/UI, so use its approved reassignment path for this race. Do not manufacture background PASS from a foreground Refresh Assignments.

PASS requires preserved upgrade/offline evidence, ordered original-identity/time acceptance exactly once, protected Needs review and owner isolation, including observed worker acceptance before reopening the app. BLOCKED means missing safe prerequisites or no observed worker execution within the diagnostic ten-minute window; preserve the artifact/evidence and investigate. FAIL/STOP means migration requests a wipe, evidence disappears, authority/identity changes, pending falsely appears accepted, duplicate/retimed effects, or another protected-boundary contradiction. Accepted observations are recorded once in this record; the combined gate gates remaining Phase 3 completion/integration and Phase 4. Physical gate **PENDING**; explicit Level 3 merge approval **PENDING**; runtime **NOT MERGED**.
