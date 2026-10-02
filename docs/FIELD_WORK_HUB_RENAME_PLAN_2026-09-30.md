# Field Work Hub — Separate Team Product Rename Plan

Date: 2026-09-30  
Decision: **Field Work Hub** is the approved new product name for the separate multi-user Team project.  
Status: **PLAN ONLY** — this document does not authorize technical-identity changes or alter an in-progress runtime phase.  
Change classification for this document: **Level 1 (documentation only)**. Subsequent changes are separately classified below.

## Identity and protected boundary

- New product name: **Field Work Hub**.
- Office/dashboard display name: **Field Work Hub Admin**.
- Android production display name when production exists: **Field Work Hub**; identify internal test builds as **Field Work Hub Internal** while the separate internal package remains in use.
- The original, working single-user **Field Photo Prep (FPP)** is a **different product** and an immutable reference for this project. Never modify its repository, app, package identity, Drive data, Supabase project, deployment, or field photos as part of this rename.
- Team's current GitHub repository `timbone72-CC/field-photo-prep-team` remains the authoritative Team repository under its **existing slug** during and after the initial branding change. The old repository slug is a technical locator, not the new product name.
- Existing approved Team roadmap behavior, phases, physical/provider evidence, branch history, CI and explicit merge gates remain in force.

## Observed current inventory (main, at planning)

- `README.md` still introduces `field-photo-prep-team`.
- `docs/ROADMAP.md` names the project "Field Photo Prep Team" and records the hard FPP/Team separation.
- `AGENTS.md` and the Change Control / Testing / Integration contracts use the historical Team name and explicitly protect the original FPP boundary.
- `dashboard/index.html` has the visible browser title "Field Photo Prep Team Admin" and visible "Field Photo Prep Team" sign-in eyebrow.
- `app/src/main/res/values/strings.xml` has `app_name = Field Photo Prep Team Internal`. The Android manifest uses `@string/app_name`.
- `app/build.gradle` currently uses Android `applicationId` / namespace `com.inandout.fieldphotoprep.team.internal` and a stable test signer. **Keep these technical identities unchanged.**
- The dashboard currently shows an example generated number `FPP-000001`. Existing and future numbering behavior is **not** within the branding rename.
- The approved HNP test Drive root and any existing Supabase URLs, roles, claims, redirect targets and provider credentials are operational infrastructure, not display names.

Before implementation, inspect the exact final heads of main and the two active draft PRs for additional user-visible labels, config references and conflict surfaces. This initial inventory is not a claim that a global repository search succeeded.

## Ordered change slices and gates

### Slice 0 — Record the decision (this PR only)

Create this single plan on an isolated documentation branch; inspect the one-file diff; check the contract and FPP separation statements. No Android or dashboard code, live data, provider settings, repository metadata or original FPP changes. The rollback is reverting this documentation PR. Documentation-only verification requires diff/contract review, not a fabricated device or provider gate.

### Slice 1 — Visible branding after the pending onboarding reality gate

Make a **separate, narrow branding PR** from the then-current Team `main`, after checking and avoiding conflicts with open PR #20 (contractor setup-link backend). Include only approved visible branding:
- `README.md`: adopt Field Work Hub as the Team product name and retain the old repository slug as an explicit locator.
- `dashboard/index.html` and any verified related *visible* onboarding copy: "Field Work Hub Admin" or "Field Work Hub" as appropriate. Do not change form IDs, script URLs, backend endpoints, cached asset/version semantics or login logic merely for the name.
- `app/src/main/res/values/strings.xml`: change only the Android-visible launcher/name and any independently verified product-name text. The internal build may say "Field Work Hub Internal" to prevent accidental confusion with eventual production or the original FPP.
- Any required current-reference documentation headers can be updated narrowly while preserving historical dates, Git identifiers, original-FPP descriptions, roadmap approval, governance rules and links. **Do not globally search-and-replace "FPP" or "Team".**

Classification: treat the combined dashboard/Android branding PR conservatively as **Level 2** (two client surfaces). Record its exact owning files, baseline, protected behavior and rollback. If the exact diff proves that no runtime/control/configuration behavior changes and contracts permit Level 1, document that narrower classification; do not downgrade by assumption.

Required checks: inspect every changed file; verify original FPP is absent from the diff; check the visible Android and dashboard names; run targeted UI/resource/build checks and the complete Android + dashboard CI on the exact final head when Level 2. An affected UI smoke check may confirm the displayed names; no repeated real-device/provider gate is necessary solely for static copy unless evidence reveals an actual launcher/install issue. Merge only under ordinary applicable Team PR gates.

### Slice 2 — Technical identifiers are deferred, not implicit

A visible-name change **does not** imply renaming:
- GitHub repository slug, existing links, branches, CI paths or action references;
- Android application ID/namespace, signing keys, installation identity, app-private storage or Room schemas;
- Supabase project, Auth callback/deep links, redirect allowlists, RLS, org IDs, secrets or hosted dashboard origin;
- existing HNP Google Drive root, folder IDs/shares or company data;
- existing/generated `FPP-` work-order identifiers, legacy historical records, photo/run/WO UUIDs or remote metadata.

Only propose a separate technical-identity change if a demonstrated operational requirement exists. For each proposed item, inspect all inbound references and provider dependencies, explicitly classify the risk (Level 3 if it touches Auth, signing, deployment, data/storage or environment boundaries), document rollback/migration and safe fixtures, run exact-head CI and affected real provider/device gates, and obtain explicit Level-3 pre-merge approval. For this rename, the default is **no technical-identity migration**.

## Preserve active work and priority

- **PR #20**, `feat/contractor-manual-setup-link-backend`, is the active Level-3 contractor onboarding gate. The required live link, second-contractor Android sign-in and Phase 2 reassignment/receipt smoke remain unresolved until proved; the naming plan must neither imply their completion nor alter that branch.
- **PR #17**, `feat/phase-3a-run-room-foundation`, is a separate unmerged Level-3 Phase 3A foundation. It needs its own database/advisor and Android device gates and operator approval. Do not rebase it merely for a cosmetic rename, or use this branding task to authorize Phase 3A.
- Record any branding merge SHA in the relevant later implementation record. Reconcile other branches against the then-current main only when their own merge preparation requires it.

## Failure and stop rules

- If a candidate "name" edit changes authorization, package identity, redirect routing, server behavior, persisted data, work-order numbering, asset loading, signing or deployment, **remove it from the branding PR** and create a separate approved impact plan.
- If the final diff touches `timbone72-CC/field-photo-prep` or FPP production/storage/data, stop: that violates the hard V1 boundary.
- If required tests fail, do not merge; repair the exact changed surface and rerun the prescribed verification.
- If current branches expose a conflicting assumption, update this plan before implementation rather than guessing.

## Completion criteria

This planning checkpoint is complete when the single-file documentation PR is recorded and reviewed for scope. The visible rename is complete only after its later narrow branding PR is verified and merged, with the Android launcher and Admin dashboard displaying the new name while original FPP and Team technical identities remain unchanged.
