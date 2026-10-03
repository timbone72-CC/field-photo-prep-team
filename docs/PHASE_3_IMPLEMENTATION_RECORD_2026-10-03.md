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


## Combined phone gate observations — 2026-10-03 America/Chicago — IN PROGRESS

Frozen runtime remains **87e57d4fc476800be96f6730e6631c23f1729536**. Operator confirmed **Works** after candidate update installation/open at 09:14, then **Works 5 WOs** after online **Refresh Assignments** at 09:15. Accept those two observations once: installation/open **PASS**, online refresh/display **PASS**. This is not yet proof of the Contractor action gate or all assignment receipts.

Read-only prerequisite check found five same-org disposable WOs, three currently assigned to one existing Contractor, one to the other and one Admin control. Two of the first Contractor's WOs remain ASSIGNED and have consistent non-null WO/run/assignment receipts; they can support the planned two-WO offline test after the phone account is confirmed. The five-WO count may indicate the Admin view, so the next exact checkpoint is to read the visible **Role** on the phone before creating field actions. No WO, assignment, account, Auth, schema or runtime was changed by this check. Physical gate remains **IN PROGRESS**, remaining evidence and explicit Level 3 merge approval **PENDING**, runtime **NOT MERGED**.


### Contractor two-WO prerequisite — 09:27 America/Chicago

The operator confirmed the initial five-WO phone view was **ADMIN**, then used an existing **CONTRACTOR** account and reported successful refresh of its one assigned test WO. On the laptop's current canonical Field Work Hub Admin page, the operator opened **TEST-0003-DASHBOARD**, selected that existing Contractor, saved the authorized ASSIGNED reassignment and reported **works**. After phone **Refresh Assignments**, the operator reported **works. Test0003**. No account creation or role change was made.

Read-only server confirmation: disposable **FPP-000001 / FWH SETUP TEST** and **TEST-0003-DASHBOARD** are both ASSIGNED to that same existing Contractor. Both have current assignment identities and matching non-null WO/run/assignment receipt projections. The latter receipt is **2026-10-03T14:27:27.500053Z**. Accepted action ledger count is zero for both. This establishes the online two-WO prerequisite; it does not claim offline/background behavior.

Frozen gate identities: first WO **a34384a5-39f4-4e37-b5a5-a51e4b9d20b1**, run **5f8664cf-20b2-46fc-9496-d117f8f02d89**, assignment **7cd18bc5-7eac-4e4c-8d96-ba9c67070231**; second WO **7f05ca30-6ccf-49f1-9b34-19f5cffdddf5**, run **503dbe4a-1d2c-454d-8244-862714b69a36**, assignment **22a32b14-780d-4f65-878a-be22b2cf1d8b**. Use the first for ordered offline Start/Finish acceptance and the second for protected offline Start versus Admin reassignment. Preserve their current local evidence and exact action times/identities. Next exact phone checkpoint: enable Airplane mode and turn Wi-Fi off before any test field action. All remaining physical gate evidence and Level 3 merge approval remain **PENDING**.


### Offline-action prerequisite contradiction — 09:32 America/Chicago — BLOCKED

Operator confirmed Airplane mode/Wi-Fi preparation at 09:30, then reported **works** for first-WO Start, **Works** for first-WO Finish and **Works** for second-WO Start. These confirmations are retained as observations of the requested controls/messages, but **offline persistence/background/race PASS is not established**.

A read-only server check before force-stop found all three actions already accepted. First-WO START **ab47ab32-ec11-4e41-a6c7-ddd6a05b1d14** event **2026-10-03T14:31:24.520389Z**, acceptance **14:31:25.089827Z**; COMPLETE **66da594d-7594-4c0d-be55-e68167333f55** event **14:31:50.338466Z**, acceptance **14:31:50.794105Z**. Second-WO START **1cb2d167-30c9-4ad1-9157-a119ee171472** event **14:32:15.544664Z**, acceptance **14:32:16.011040Z**. Each result is APPLIED on the frozen WO/run/assignment instance, with original event time preserved. First WO is FIELD_COMPLETE and second is IN_PROGRESS. Accepted immutable evidence remains untouched.

The phone had a usable network path during these submissions; its actual connectivity or the device used to send chat replies must be clarified. This is a missing offline prerequisite, not a proven software defect or a background-scheduling pass. Pause the restart/race/reconnect sequence; do not force-stop, clear evidence, reset status or pretend these accepted actions remain pending. Next exact checkpoint: establish whether chat replies are sent from the test phone or laptop, then verify network isolation before any replacement disposable offline gate. Replacement fixture setup must retain these accepted records and use the existing Admin authority. Runtime, accounts, schema, package/signer and recovery are unchanged. Remaining physical gate **BLOCKED**, Level 3 merge approval **PENDING**, runtime **NOT MERGED**.


### Wi-Fi cause established; fresh disposable gate staged — 09:40 America/Chicago

The operator clarified that Airplane mode was on but Wi-Fi remained on, explaining immediate acceptance in the first attempt. No software defect is established. Those original accepted records remain retained; no reset/rebinding/data deletion is used. The operator requested grouping easy phone/laptop steps, superseding the prior one-control-per-response pacing for straightforward portions of this same approved gate.

Through the existing Admin UI the operator created **TEST-P3-SYNC-1003** and **TEST-P3-CONFLICT-1003**, both synthetic TEST ONLY addresses/work type, due 2026-10-03 and assigned to the same existing Contractor, then reported **Works** after phone Refresh Assignments. Read-only confirmation: both ASSIGNED, accepted-action counts zero, current assignment identities present, non-null matching WO/run/history receipt at **2026-10-03T14:40:18Z**.

The replacement physical gate is frozen to SYNC WO **7cbacf70-2080-4a5c-9db1-f7b8314fb91e**, run **249dd0ad-acb0-4dec-80bc-d783571b7503**, assignment **2298bf5a-73ae-4365-9592-8b5e80bf697c**; CONFLICT WO **fb47a5c3-9295-4dcf-90af-db5e2a897be1**, run **f73c7812-8f0f-47cd-afe8-a04da620247d**, assignment **c0921d8b-1386-42bc-8229-48cc156f7770**. This narrow fixture replacement resolves the missing offline prerequisite without changing approved behavior, runtime 87e57d4, schema, Auth or accounts. The prior passed install/online evidence is retained.

Next grouped checkpoint: Airplane mode ON and Wi-Fi explicitly OFF; remain offline while Start/Finish SYNC and Start CONFLICT show pending labels; force-stop through Settings → Apps → Field Work Hub Internal and reopen offline; confirm both pending states survive. Send chat response from the laptop so replying cannot reconnect the test phone. The later Admin race and ordinary-background reconnect remain dependent on this offline-persistence observation and a read-only zero-acceptance check. Physical gate **IN PROGRESS**, background/conflict/isolation evidence **PENDING**, Level 3 merge approval **PENDING**, runtime **NOT MERGED**.


### Replacement offline actions and restart — 09:47 America/Chicago — PASS

Operator reported **everything passed as far as i can tell** after the grouped instructions: Airplane mode ON and Wi-Fi OFF; SYNC Start then Finish showing field-complete waiting-to-sync; CONFLICT Start showing started waiting-to-sync; Settings → Apps → Field Work Hub Internal → Force stop; offline reopen with both pending labels retained. Accept this as operator-reported offline action/reconstruction evidence on runtime 87e57d4, without claiming direct local database inspection.

Read-only server check at this checkpoint confirms both fresh WOs still ASSIGNED to their original Contractor with started_at/field_completed_at null and **zero accepted action rows**. This corroborates that their progress is local and unresolved, unlike the first connected attempt. No repeat of accepted Phase 3A downloaded-list proof is needed.

Next exact checkpoint: keep the phone offline; in Admin Edit / Reassign only **TEST-P3-CONFLICT-1003** to the other existing same-org assignable Contractor and Save Changes. SYNC stays assigned to the original owner. Verify the authorized assignment-instance change and zero accepted actions before normal-background reconnect. This race intentionally leaves protected local progress on its original owner/instance; it must not be reset, deleted, approved as a handoff or rebound. Conflict/background/isolation observations and Level 3 merge approval remain **PENDING**; runtime **NOT MERGED**.


### Authorized offline reassignment race established — 09:50 America/Chicago

Operator reported **Works** after Admin Edit / Reassign of **TEST-P3-CONFLICT-1003** to the other existing Contractor. Read-only confirmation at **2026-10-03T14:50:26.417792Z**: CONFLICT remains ASSIGNED, no server start/completion or accepted actions; current assignment instance changed to **9a286956-5cf2-4618-afd7-6ee4b65ca19e**, beginning **14:49:46.964945Z**, with the other existing Contractor. Its locally queued START remains bound to old assignment **c0921d8b-1386-42bc-8229-48cc156f7770** and original owner. SYNC stays ASSIGNED to the original owner on unchanged instance **2298bf5a-73ae-4365-9592-8b5e80bf697c**, with no server start/completion or accepted actions.

Next exact checkpoint: the phone app has already been reopened offline following force-stop. Press Home for ordinary backgrounding, restore connectivity from Android controls without reopening FWH or tapping Refresh Assignments, and report Next from the laptop. Then observe only these exact WO/ledger identities read-only for the diagnostic window before any app reopening. Only observed START/COMPLETE acceptance with the app continuously backgrounded can establish this boundary; CONFLICT must remain unauthorized. Physical background/race result **PENDING**, owner-isolation result **PENDING**, Level 3 merge approval **PENDING**, runtime **NOT MERGED**.
