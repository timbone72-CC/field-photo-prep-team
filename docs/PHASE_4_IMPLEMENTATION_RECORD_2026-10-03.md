# Phase 4 photos — implementation record

Scope key: `phase-4-photos`. Change level: **Level 3**.
Authoritative branch: `feat/phase-4-photos`; draft PR **#35**.
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

Implementation IN PROGRESS. Runtime, migration, focused regression and final exact-head CI proof PENDING. FWH migration `20261003211226_phase_4_photo_requirements` is applied and mirrored; live rolled-back authority/count/digest/replay fixtures PASS. Final candidate/recovery artifacts PENDING. Combined laptop/phone gate PENDING. Explicit Level 3 merge approval PENDING; runtime merge NOT AUTHORIZED.

Complete local/disposable SQL and Android/Admin checks before applying tested mirrored live DDL. Recheck grants/RLS, deployed bodies, baseline preservation and security/performance advisors. Then produce immutable candidate and recovery artifacts for one combined physical gate from the approved plan. Record actual pass/block/fail results and exact next gate here.

## Implementation checkpoint

Draft runtime checkpoint `deb1bb1ff6ce0f3308c9549e291fdab4adf28a6e` implements the single requirement model, optional template/default settings, pre-Start atomic Admin edits, configured protocol guards, frozen metadata validation, Room v3, permanent capture reservations, CameraX any-order UI, separate JPEG preparation, confirmed single-photo discard intents and exact Finish sets in the existing action coordinator.

Local disposable PostgreSQL (PGlite, UTC) migration chain and Phase 3A/3/4 SQL gates PASS. This is preliminary SQL proof; PostgreSQL 17.6 CI and real multi-connection races remain required. Admin syntax and 19 regression tests PASS. No hosted DDL applied yet. Android compile, focused/complete regression, v3 schema export and actual candidate/recovery identities remain pending CI. Initial workstation package installation was unavailable; use disposable/CI proof without changing system permissions.

Checkpoint `23665a88ac8f159d43f1cd2e6165c16c5544fa86`: complete Android, Admin and PostgreSQL 17.6 SQL/multi-connection checks PASS; candidate v6/recovery v7 built with verified stable package/signer. Android run 37153750625, Admin 37153750690, DB 37153750709. Room v3 export copied from that successful CI artifact. Additional camera-screen callback isolation and recovery tests are being verified before offering artifacts. First migration fixture failure was fixed by supplying the actual legacy `{}` snapshot; malformed configured snapshots still fail closed.

Hosted pre-DDL body/grant parity PASS for established assignments, acceptance and all five mutation owners, including the latest Contractor-only Admin create function. Baseline security advisors retain the accepted leaked-password WARN and invitation INFO; performance contains only unused-index INFO. Current official Supabase minor-upgrade notes reviewed; this migration uses no ltree, legacy PGP ciphers, NaN GiST or custom operators.

Exact pending migration `phase_4_photo_requirements`: new photo_templates and photo_finish_sets ledgers; additive field_actions revision/set/digest and photos item/revision/set/assignment columns; requirement snapshot validation/protection; atomic Admin v4 create/update/configuration and template save RPCs; v4 action and frozen-metadata registration RPCs; established legacy mutation guards and current membership checks. Hash/digest validation binds immutable Finish payloads. No business backfill, byte delivery or destructive rollback. Apply only after the matching disposable CI gate, mirror its actual hosted version, then run rolled-back live fixtures, preservation/parity and advisors before staging.

## Hosted backend checkpoint

Migration **20261003211226** applied from tested SQL (PostgreSQL 17.6 CI run 37154125360 / 37154253044); the CLI-created draft filename was replaced with the actual recorded hosted version. Live Phase 4 authority/count/revision/digest/legacy/replay fixtures PASS and fully rolled back. Fresh pre/post checks using the same ordered string-aggregation method preserve eight WOs, five accepted actions, zero photos/templates/sets. WO hash `69d57abe13965e0ee193cbaa383e1249`, run hash `a3ce6f0c188b6d270030a508b6f85a8c`, normalized action hash `3687b01df5a9f06672e0ad077c815925`, photo hash `d41d8cd98f00b204e9800998ecf8427e`. New action columns are excluded when comparing original historical facts. These immediate pre/post hashes are the DDL preservation proof; early preflight hashes above remain separate because their aggregation/session representation was not reproduced.

Deployed new function bodies/grants/search paths match source; public wrappers are invoker, private implementations enforce current membership, and authenticated clients cannot call the preserved legacy acceptance helper. Security baseline unchanged. Performance advisors found two new JWT-initplan warnings; a same-authority repair is being tested and mirrored before staging.

Android `7634124bd2d7a7e2590a29f0aeeb888a696cf1a5` focused and complete tests, v1/v2/v3 migration proof, byte-preserving preparation/orientation, Room restart and shutter/Finish race tests PASS (run 37154253050). Preparing the final head with the hosted migration mirror and recovery read-only guards; no device installation or physical gate has occurred.

Same-authority advisor repair applied as **20261003211841** and exactly mirrored. Both new JWT-initplan warnings are gone; no new security notices and performance only unused-index INFO. The complete baseline plus two Phase 4 migrations is 23 versions. Camera preparation uses partial state updates so a concurrent Finish membership is never overwritten. Recovery now blocks handoff and refresh-side network mutations and reads cached evidence only. Final exact-head verification and physical staging are next.
