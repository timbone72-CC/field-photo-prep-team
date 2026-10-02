# Field Work Hub — Project Governance

## Purpose and authority

This is the universal work-control layer for the separate Field Work Hub (FWH) project. It adapts proven FPP governance without adopting FPP's single-user architecture or modifying FPP. Feature details remain in FWH's existing contracts and approved roadmap. Use the largest coherent change that can be understood, safely reversed, and verified.

## Operating cycle

1. **Discover:** read governed main, relevant open PRs/branches, the active implementation record, and affected live-system state before taking over work.
2. **Classify:** record goal, scope key, affected surfaces, Level 1/2/3, authoritative branch, rule packs, protected behavior, external systems, rollback, and verification.
3. **Continue:** use the existing authoritative line if it already owns the scope. Do not silently restart overlapping work from main.
4. **Implement in the owner:** prefer the largest safe coherent batch; no duplicate authorization, offline, photo, queue, or remote-write path merely to avoid an existing design.
5. **Verify proportionally:** focused evidence during implementation; one final complete suite on the exact runtime head when required; smallest genuine device/provider gate.
6. **Reconcile external state:** source, approved migrations/configuration, real deployed state, and recorded physical evidence must agree.
7. **Handoff:** maintain a durable resume point with exact next checkpoint and unresolved gates.
8. **Close:** evidence, external state, cleanup decisions, roadmap, approval, and merge/deployment state must tell the same story.

## One authoritative implementation line

Only one branch/PR may be authoritative for materially overlapping scope. Before creating a new line, inspect all open PRs, relevant branches and the last durable build-state record.

If replacing a line, explicitly record the reason, what tested or untested work carries forward, the replacement branch/PR, and the old line's disposition. Do not close a branch solely to make GitHub's duplicate-scope check pass. Independent changes may proceed concurrently only when their ownership and touched surfaces do not conflict.

## Source of truth and external-state parity

- Completed code, contracts and approved roadmap: governed FWH main.
- In-progress changes: main **plus** the single authoritative PR/branch, its impact/build-state record and any legitimate live state already changed for that scope.
- Supabase schema, migrations, RLS, grants, Auth callbacks and Edge Functions: reconcile deployed Team state against the exact authoritative line; never infer from main alone while a Level-3 change is pending.
- Team Android packages/signers, hosting and CI configuration: record environment, revision and rollback when modified.
- Company-controlled HNP Drive objects/photos are operational data, not Git-controlled configuration; verify provider truth at the appropriate roadmap gate without manufacturing live work.
- If a persistent external configuration cannot be stored in source, record its non-secret value/class, purpose, environment, verification and rollback in the active record.

Material contradictions stop the affected implementation until reconciled. Never create a substitute backend or rename a technical identity because current main lacks an in-progress change.

## Protected scope and project separation

FWH is the multi-user, offline-capable work-order system; FPP is the separate working single-user photo product. FPP may be read as a proven reference only. FWH work must not mutate FPP's repository, app, package, authentication, storage, permissions, production files or field data.

Preserve FWH's server-controlled organization/role/assignment authority, protected offline evidence, immutable work-order/run/photo identities, fail-closed uncertain remote outcomes and exact server-mediated delivery. No governance/branding task silently changes them.

## Classification, approvals and batching

The existing CHANGE_CONTROL_CONTRACT.md defines Level 1/2/3 and approvals. If uncertain, classify upward; scope expansion requires reassessment. Level 3 always requires **explicit operator pre-merge approval**. Design approval and a PR field marked APPROVED are not independent proof of that operator decision.

Do not repeatedly request permission for unchanged approved Level 1/2 work. Build through the largest safe verifiable batch and stop only at real decisions, contradicted physical/provider evidence, required failures, unapproved scope or the Level-3 merge gate.

## Durable handoff and closeout

For each active Level 2/3 scope, keep one authoritative impact/build-state record with baseline and rollback SHA, branch/PR and current head, implemented scope, external state touched, passed and incomplete evidence, blocked risks, next exact gate, and operator approval/merge status.

A scope is not complete until implementation, required automated and real evidence, live configuration parity, consciously retained or cleaned disposable fixtures, roadmap/current status and merge state agree. Do not relabel pending work as complete because the code compiled.

## GitHub's limited enforcement

GitHub can check mandatory PR metadata, exact branch name, duplicate declared scope keys, obvious sensitive-path minimum levels, and CI status. With repository-admin protection, it can also require PRs/checks, block force pushes/deletions and require resolved discussions. It cannot establish correct rule-pack selection, verify physical evidence or authenticate an operator approval where automation shares an identity. These remain human/contract responsibilities. A workflow file is not branch protection: verify admin-side settings before claiming hard enforcement.

## Precedence

When documents materially disagree, stop the affected path and reconcile:
1. GOVERNANCE.md for universal work-control procedure;
2. PROJECT_PROFILE.md for FWH architecture and project boundary;
3. CHANGE_CONTROL_CONTRACT.md, TESTING_CONTRACT.md and INTEGRATION_CONTRACT.md for their respective detailed rules;
4. approved docs/ROADMAP.md plus scope-specific design/impact record for permitted behavior and phase boundaries;
5. current scope build-state/handoff for observed status, never for overriding contracts.

AGENTS.md is the short entry point and RULE_INDEX.md selects the relevant packs. Lower layers may add detail, not silently override higher authority.
