# Phase 4 photos — implementation record

Scope key: `phase-4-photos`. Change level: **Level 3**.
Authoritative branch: `feat/phase-4-photos`; draft PR pending creation.
Baseline: main `a7d5806df00df71bfb074af1dc0ce14a67a08c20`.

## Approved scope and authority

Implement the whole approved `docs/PHASE_4_IMPLEMENTATION_PLAN_2026-10-03.md`, including optional inspector walking/display order. User approved the parent plan on 2026-10-03 and instructed continuation after its merged clarification. Sections 4A–4E are one implementation batch. Level 3 merge approval remains PENDING.

Affected owners: FWH Admin dashboard, narrow SQL requirements/template and frozen photo metadata RPCs, existing action acceptance and mutation serialization, additive Room v3, one protected capture/preparation owner, existing session/action coordinator and phone UI, focused SQL/JVM tests, CI and candidate/recovery builds. No Drive upload, original FPP changes, new Auth accounts, general cleanup or route enforcement.

Requirement snapshots belong to the exact run and freeze at local and server START. Admin settings affect unstarted runs only. Every requirement is optional; each photo belongs to one enabled item or Extra. Total is independent; minimum unique photos is max(total minimum, sum of enabled item minima). Inspectors may visit any item in any order.

One permanent UUID binds each original to actor/org/WO/run/assignment/revision before camera writes. Room owns reservations, valid evidence and immutable Finish set/action. Files remain protected; preparation only publishes a separate derivative. Server authority rechecks active account, exact assignment/revision and distinct frozen metadata before COMPLETE. Metadata acknowledgement does not acknowledge remote byte delivery.

Offline actions and originals survive restart, account changes, reassignment, cancellation and revision conflicts. Conflicts preserve evidence and show Needs review; no silent rebind. Legacy unconfigured Phase 3 actions retain their accepted/replay semantics. Configured runs require the new protocol even when all requirements are off.

## Preflight and preservation

Mandatory governance packs, complete parent plan and Phase 4/5 roadmap sections read. Main matched the baseline; no open overlapping PRs. FWH backend only: `vyocaujuwrivoqynvitm`, PostgreSQL 17.6, 21 mirrored migrations. Baseline contains eight work orders, five accepted actions and zero server photos. Work-order hash `823382f8852c965601fbbda5c535a37f`; run hash `f1cfc08f6dbbc9b52651b9fb67e0fc73`; action hash `8ca56d2e79a4e44bd3da639330cce6b7`; photo hash `d41d8cd98f00b204e9800998ecf8427e`. Existing business records must remain unchanged by migrations and rolled-back fixtures.

## Exact recovery steps

Before candidate installation, build and verify a higher-version same-package/signer recovery APK retaining Room v3, migrations v1→v2→v3 and protected evidence, with new capture, metadata/action submissions and scheduling disabled. Candidate/recovery version codes are 6/7. Verify package, signer, schema and manifest/version metadata from the actual APKs. On a device blocker install that verified recovery update over the candidate; do not downgrade, uninstall or Clear data. Read-only evidence remains available.

Server recovery retains additive requirements, metadata and accepted action ledgers. Disable affected client submission paths, preserve identity evidence and use a narrow forward repair under this record. Do not drop tables, reset work orders or delete protected photos. Source rollback starts from the baseline above but must retain v3-compatible recovery; an old v2 APK is not a device recovery.

## Current status and next gate

Implementation IN PROGRESS. Runtime, migration, focused regression and final exact-head CI proof PENDING. No Phase 4 live DDL applied. Candidate/recovery artifacts PENDING. Combined laptop/phone gate PENDING. Explicit Level 3 merge approval PENDING; runtime merge NOT AUTHORIZED.

Complete local/disposable SQL and Android/Admin checks before applying tested mirrored live DDL. Recheck grants/RLS, deployed bodies, baseline preservation and security/performance advisors. Then produce immutable candidate and recovery artifacts for one combined physical gate from the approved plan. Record actual pass/block/fail results and exact next gate here.
