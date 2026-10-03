# Phase 3 combined offline actions and background sync — implementation record

Scope key: `phase-3-offline-actions-sync`. Change level: **Level 3**.
Authoritative branch: `feat/phase-3-offline-actions-sync`; draft PR to be recorded after first checkpoint.
Baseline / recovery source: main `8a33ff7490716ea35520c8f97085cfee4f0883be`.

## Authority and scope

Implement the remaining Phase 3B/3C together under `PHASE_3_IMPLEMENTATION_PLAN_2026-10-02.md`. The original approved Phase 3 scope, detailed 3B approval on 2026-10-02 and operator **Next** on 2026-10-03 authorize this unchanged runtime batch. PR #30 consolidated the complete parent plan; PR #31 clarified governance. Existing Phase 3A phone/backend evidence is retained, not restarted. This is the single runtime line; preflight found no open overlapping PRs and main matched the baseline.

Affected surfaces: FWH narrow SQL acceptance/ledger and serialized existing mutations; additive Room v1→v2; durable START/COMPLETE actions and reconciliation; shared encrypted session coordination; MainActivity controls; constrained one-time WorkManager; focused SQL/JVM tests and Android CI. Required packs: AGENTS, GOVERNANCE, PROJECT_PROFILE, RULE_INDEX, CHANGE_CONTROL, TESTING, INTEGRATION, parent roadmap/plan and PHASE_STAGING_DOCTRINE.

Protected behavior: owner/org isolation, immutable WO/run/assignment/action identity and original device event time, preserved offline evidence, current server authority and consent/receipt projections. FPP, photos/camera/Drive, onboarding, unrelated dashboard features and accounts are outside scope.

External systems: only FWH Supabase `vyocaujuwrivoqynvitm` (migration mirror/parity, controlled rolled-back fixtures, advisors) and this GitHub runtime branch/CI. No customer data changes or new accounts are planned.

## Recovery

Room upgrade is additive and must not use destructive fallback. Once v2 is installed, recovery is a higher-version same-package/signer build retaining v2/action rows, with action submissions and scheduling disabled. No downgrade, uninstall, Clear data or evidence deletion. Prepare and verify the recovery variant before staging the candidate; preserve ledger/migrations rather than destructive SQL rollback.

## Verification and handoff

Status: **IN PROGRESS** — preflight reads/main/open-PR/migration inventory completed; five current mutation owners identified. Source/body/grant parity and runtime implementation are next. Existing 19 live migrations match the baseline inventory.

Focused queue/storage/backend proof precedes worker integration; final exact-head Android/Admin suites follow once. Then stage one immutable candidate APK plus recovery APK, and run the single combined phone/laptop gate in the parent plan. Actual background acceptance must be observed without opening the phone app or tapping Refresh Assignments; force-stop persistence is a separate step.

Physical gate: **PENDING**. Final exact-head CI: **PENDING**. Live migration changes: **NONE YET**.
Level 3 merge approval: **PENDING**. Runtime merge: **NOT AUTHORIZED / NOT MERGED**.
