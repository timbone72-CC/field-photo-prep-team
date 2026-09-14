# Field Photo Prep Team Agent Guardrails

Field Photo Prep Team is a multi-user field-photo system with real risks around work-order ownership, offline state, photo identity, authorization, reassignment, upload destination, and destructive retry. Every human or automated agent must follow these rules before changing approved behavior.

## First-action mandatory read

At the start of **every work session**, before changing runtime code, tests that define runtime behavior, database schema, authentication/authorization, offline behavior, photo handling, upload behavior, deployment, or signing:

1. Read this `AGENTS.md` completely.
2. Read the relevant phase in `docs/ROADMAP.md` completely.
3. Read `CHANGE_CONTROL_CONTRACT.md`.
4. Read `TESTING_CONTRACT.md`.
5. Read `INTEGRATION_CONTRACT.md` whenever the change touches Supabase, RLS, Auth, Room/local persistence, offline synchronization, reassignment, camera/photo state, background work, Google Drive/storage, upload, retry, or cleanup.

Documentation-only work must still read this file and the document being changed.

Do not substitute a chat summary, memory, prior-session notes, or an earlier read for these mandatory reads.

## Phase-plan gate — mandatory STOP condition

**Do not implement a roadmap phase until its behavior, failure handling, protected boundaries, verification strategy, and completion gate are documented and approved.**

Before starting implementation for any phase, confirm that `docs/ROADMAP.md` defines at least:

- the user-visible workflow;
- server-authoritative vs local-authoritative facts;
- offline/restart behavior where applicable;
- conflict/reassignment/cancellation behavior where applicable;
- protected data and identity rules;
- expected failure behavior;
- implementation boundaries/slices;
- automated verification;
- physical-device/reality gates where software tests are insufficient; and
- the phase completion gate.

If any required part is materially undefined, **STOP implementation and plan the phase first**.

If new evidence invalidates a phase assumption, **STOP the affected path and update the plan before continuing**. Do not improvise a new product rule inside runtime code.

## Phase-transition mandatory reread

When moving from one roadmap phase to the next:

1. reread this file;
2. reread the completed phase gate and evidence;
3. reread the next phase in `docs/ROADMAP.md` in full;
4. confirm unresolved decisions are explicitly identified;
5. confirm the next implementation slice does not depend on an unproven device/provider assumption.

A phase transition is not authorized merely because the previous phase compiled or because a prior chat said “next.”

## FPP reuse rule

The existing single-user `timbone72-CC/field-photo-prep` project is a proven design and development reference, but **it is not a Team test surface and must not be modified by Team work**.

Reuse from FPP in two ways:

1. **Product behavior:** carry forward proven photo-protection, capture, preparation, queue, retry, uncertainty, identity, restart-recovery, and device-gate behavior where Team requirements do not conflict.
2. **Development workflow:** carry forward mandatory reads, risk classification, isolated branches, focused tests during development, one final complete automated suite, proportional reality gates, rollback points, and explicit stop conditions.

Do not copy FPP internals merely because they exist. Team may require different implementation choices because it is multi-user, server-authorized, and offline-first.

## V1 hard boundary

Team work must never modify, migrate, deploy, delete, or use the working Field Photo Prep V1 repository/app/data as a Team experiment surface.

Repository boundary:

- Team: `timbone72-CC/field-photo-prep-team`
- V1 reference only: `timbone72-CC/field-photo-prep`

If a Team task appears to require a V1 runtime change, **STOP and ask for explicit scope expansion**.

## Choose the smallest honest change class

### Level 1 — low risk

Examples:

- documentation;
- comments;
- noninteractive wording;
- appearance-only changes that cannot alter authorization, work-order ownership, stored state, photo identity, capture, upload, deletion, or deployment.

Use an isolated branch, inspect the diff, and perform only checks appropriate to the changed surface.

### Level 2 — normal feature or fix

Examples:

- ordinary dashboard or Android UI;
- non-destructive controls;
- display/status logic;
- narrow client behavior that does not change persisted schemas, authorization boundaries, assignment semantics, photo identity, upload identity, or destructive behavior.

Use an isolated branch and PR. Record scope, ownership, protected behavior, focused tests, rollback point, and affected smoke checks. Run focused tests during development and the complete automated suite once on the final runtime head before merge.

### Level 3 — high risk

Examples:

- Supabase schema/migration changes;
- RLS/Auth/role/organization authorization changes;
- Room or other persisted local schema changes/migrations;
- offline write queue, conflict, reassignment, or cancellation semantics;
- photo identity or protected-original behavior;
- background sync or retry authority;
- Google Drive/storage authorization, destination identity, upload, reconciliation, or cleanup;
- deletion/destructive actions;
- app signing, production deployment, or environment-boundary changes.

Use a dedicated branch and PR, detailed impact record or equivalent roadmap-approved implementation record, realistic safe fixtures, explicit rollback, focused tests, final complete automated verification, affected physical/device/provider checks, and **explicit operator approval before merge**.

When uncertain between two levels, use the higher level.

## Authorization without permission loops

- The user's approved request authorizes the documented scope.
- Do not repeatedly ask for the same approval while scope remains unchanged.
- Ask again only when scope expands, a governing assumption proves false, or Level 3 pre-merge approval is required.
- An audit finding is not automatic authorization to implement an adjacent change.

## Public-repository safety

This repository is public. Never commit:

- passwords;
- Supabase service-role/secret keys;
- OAuth client secrets or refresh tokens;
- Google account credentials/recovery codes;
- contractor personal data beyond approved runtime/test-safe references;
- real HNP customer data or uploaded field photos;
- production signing secrets.

Publishable client keys and non-secret project identity may be present only where the architecture explicitly permits them.

## Supabase rules

Before Supabase changes, read current relevant Supabase documentation and the existing migration chain.

- Use migrations for DDL and mirror every applied migration under `supabase/migrations/`.
- Run Supabase advisors after DDL changes and report the result.
- RLS is a server authorization boundary, not a UI convenience.
- Do not use user-editable metadata for authorization facts.
- Do not expose service-role/secret credentials to Android or browser clients.
- Prefer narrow server-authorized RPCs for privileged actions instead of broad client table permissions.
- Treat JWT authorization claims as potentially stale until refreshed.
- Do not fake Auth identities by inserting rows into `auth.users`.

## Offline and local-state rules

Team is intentionally offline-capable.

- Local cached work must never be silently presented as confirmed server state when it is not.
- Offline field actions must preserve enough durable local evidence to retry/reconcile safely.
- A server-side reassignment/cancellation must not silently destroy locally started work.
- Do not invent conflict resolution in UI code; it must be an approved domain rule.
- Local persistence is app-internal. Contractors must not be asked to configure databases or storage systems manually.

## Photo-protection rules

These FPP-proven principles are protected unless the Team roadmap explicitly replaces them:

- a permanent photo identity exists before capture;
- protected originals survive preparation/upload/network failure;
- prepared/compressed copies are separate from protected originals;
- captured photos remain bound to the exact Team work-order identity;
- restart must not discard unconfirmed field evidence;
- upload success is not claimed until confirmed remotely;
- uncertain remote outcomes fail closed and are reconciled before blind retry;
- confirmed remote identity/destination evidence is preserved for duplicate prevention;
- local originals are not removed until remote success and local bookkeeping are durably confirmed;
- Team is not a permanent local photo library after safe remote completion.

## Ownership and narrow scope

Keep responsibilities explicit:

- Supabase/Auth/RLS owns server identity and authorization;
- Room/local persistence owns offline durable device state once Phase 3 authorizes it;
- field workflow owns local start/complete intent and reconciliation status;
- camera owns capture/lifecycle only;
- photo storage owns protected originals/prepared derivatives;
- sync owns pending actions and photo-transfer state;
- remote-storage integration owns exact destination/remote identity and confirmed outcomes;
- UI requests actions and renders state; it must not become a second persistence or authorization implementation.

Do not turn a fix into cleanup, redesign, framework expansion, renaming, or feature growth without approval.

## Straight-line development doctrine

Within an approved phase:

**build everything that can be honestly proven without the phone → stage at the next genuine physical-device boundary → run the smallest required reality gate → accept the evidence → adjust only where reality requires it → continue.**

Do not stop after every small code edit for a phone check when automated evidence is enough. Do not continue past a boundary where the next design decision materially depends on unverified physical Android, camera, lifecycle, connectivity, or storage-provider behavior.

## Verification

`TESTING_CONTRACT.md` owns test selection and timing.

- During development, run focused tests for the changed behavior.
- After fixing a focused failure, rerun that focused test first.
- Before merging runtime changes, run the complete automated suite once on the exact final runtime head.
- Required test failure stops merge/publication/deployment.
- Physical-device evidence is required only for behavior automated tests cannot honestly prove.
- Record real-device evidence once; do not repeat reality gates merely for reassurance.

## Merge and release stop conditions

Stop merge/publication/deployment when any of the following is true:

- required phase behavior is still undefined;
- scope expanded without approval;
- a required test failed;
- a real device/provider result contradicts the plan;
- authorization boundaries are unverified;
- local/server state could be silently lost or misattributed;
- photo identity/destination is ambiguous;
- upload outcome is uncertain and the design would blindly retry;
- a Level 3 change lacks explicit pre-merge operator approval.

## Governing principle

**Build small now, avoid choices that trap us later. Reuse proven FPP behavior and process where it fits. Plan before coding. Build to evidence, not assumptions.**
