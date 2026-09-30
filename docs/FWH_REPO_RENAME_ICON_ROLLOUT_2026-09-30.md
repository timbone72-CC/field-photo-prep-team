# Field Work Hub — Repository Rename and Approved App Icon Rollout

Recorded: 2026-09-30  
Request: Rename the **separate Team repository** from `timbone72-CC/field-photo-prep-team` to **`timbone72-CC/field-work-hub`**; adopt the operator-approved FWH hub/network icon so Android users cannot confuse FWH with the original Field Photo Prep (FPP).  
This document: **Level 1 planning only**. It does not perform the GitHub rename, deploy links or change an APK. The execution steps below must observe their own risk/approval gates.

## Protected identities and current truth

- FPP repo `timbone72-CC/field-photo-prep`, FPP APK, Supabase, data and Drive are **completely out of scope** and must not be changed.
- Preserve Team's Git history, open PRs and branches, active `main` governance ruleset and its three required GitHub Actions checks. Preserve the existing Team Android package `com.inandout.fieldphotoprep.team.internal`, existing stable test signer and app-private data; this is an **icon and label update**, not a reinstall/migration.
- Do not change FWH Supabase project ID, organization IDs, Auth accounts, RLS, work-order UUIDs or the existing `FPP-` work-order number prefix. Visible branding must not alter any business identity.
- Approved icon: the distinct operator-accepted FWH design showing **FWH lettering inside a colored network/hub with a location pin**, deep blue/teal background. Use the approved source image, not an independently redesigned replacement. Preserve a high-resolution source plus Android launcher foreground/background/monochrome and legacy mipmap outputs when implementing. Protect the artwork's recognizability at launcher size and Android adaptive-icon masks.
- Approved user-visible labels: `Field Work Hub` (production, when authorized), `Field Work Hub Internal` (existing internal Android install) and `Field Work Hub Admin` (dashboard).

## Verified dependency inventory

1. Team `main` hosts the Admin dashboard with `.github/workflows/pages.yml` on GitHub Pages and the folder `dashboard/`. The repository slug contributes to the project Pages URL.
2. Pending **PR #20**, authoritative `feat/contractor-manual-setup-link-backend`, currently has this trusted Edge Function fallback:
   `https://timbone72-cc.github.io/field-photo-prep-team/contractor-invite.html`.
   It also supports the `TEAM_INVITE_REDIRECT_URL` environment override. Its Supabase generate-link operation uses the configured URL and is still gated on live second-contractor onboarding evidence.
3. The Supabase project's **actual deployed** Edge Function env/redirect allowlist and existing live Pages URL must be inspected; code alone does **not** prove which URL currently operates. Do not change or guess secrets.
4. Team `main` still has historical launcher label in `app/src/main/res/values/strings.xml` and a CI check for that exact old APK label in `.github/workflows/android-ci.yml`; the branding PR must change the resource and its CI assertion together.
5. `dashboard/index.html` and the contractor setup page in pending PR #20 have the previous product-facing names. Avoid parallel edits to PR #20's onboarding flow; reconcile copy only after its current live gate and controlled merge.
6. The current FWH main ruleset requires jobs `governance`, `build` and `dashboard`. A rename must preserve it and verify these **live exact names** after relocation.
7. PR #21 recorded the separate product branding plan and was merged. PR #17 (Phase 3A) and PR #20 (onboarding) remain separate Level-3 draft implementations; no approval or smoke result is implied by the naming request.

## Stage 1 — Dependencies BEFORE the GitHub repository rename

1. Read current FWH `AGENTS.md`, `GOVERNANCE.md`, `PROJECT_PROFILE.md`, `RULE_INDEX.md`, `CHANGE_CONTROL_CONTRACT.md`, `TESTING_CONTRACT.md`, relevant roadmap sections, `INTEGRATION_CONTRACT.md` for Auth/Pages boundary work, and the latest authoritative branch records.
2. Inspect **real** current GitHub Pages deployment URL, Supabase site/additional redirect allowlist and deployed `TEAM_INVITE_REDIRECT_URL` status. Check whether any issued and still valid invite links depend on the old Pages path; do not expose or store actual invite links in this public repo. Avoid changing the in-progress PR #20 implementation while its provider gate is unresolved.
3. Prepare and separately approve a narrow **Level 3** hosting/redirect cutover plan if the actual URLs are in use. Preauthorize the new Pages URL in Supabase Auth when applicable; ensure the trusted Edge Function uses the correct explicit environment URL and PR #20's source fallback can move to the new URL without deploying prematurely. Preserve secure origin rules. Where possible, complete onboarding's existing live reality gate first, so rename cannot mask an existing failure.
4. Document what happens to any old still-valid contractor URLs. Do not assume that GitHub repository HTTP redirects also redirect old **GitHub Pages** URLs. Stop a rename if the safe cutover or recovery for legitimate existing links is unproven.

## Stage 2 — GitHub metadata rename, separately gated

The connected GitHub toolset does not expose a repository-name update endpoint. The repository administrator must perform the UI operation after Stage 1 gates: GitHub old Team repository **Settings → General → Repository name → `field-work-hub`**. First confirm GitHub accepts the new name; if unavailable, stop and select a new slug deliberately rather than create a second repo.

Immediately verify the **same repository identity**/history, default `main`, existing open PR numbers and branches, `FWH Main Protection` ruleset, no bypass, required check contexts, Actions permissions, Pages configuration and deployed site. Update the developer laptop's git `origin` URL to the new canonical repository. Check FWH GitHub clone/PR links and workflows explicitly; GitHub repo redirects may help but are not a substitute for updating maintained links. Never rename the original FPP repository.

If Pages or Auth callback verification fails, stop onboarding/release use and apply the preapproved Pages/redirect rollback. Renaming the repo back must not be assumed to restore a previously broken real invite link without retesting.

## Stage 3 — Controlled visible app/dashboard branding and icon

In a separate **Level 2** FWH-only PR from then-current main, after confirming open PR #20 overlap:
- Add the **approved exact icon source** and appropriately generated Android adaptive launcher resources/mipmap fallbacks. Confirm no FPP branding/icon resource was copied into FWH or vice versa.
- Set existing internal Android app's visible launcher label to `Field Work Hub Internal`; preserve package ID, test signer and all local storage.
- Update `.github/workflows/android-ci.yml`'s APK label assertion in the same commit and confirm built APK package, label, launcher asset and signing certificate. Check icon contrast and cropping with real launcher/adaptive shapes using the smallest needed Android UI check.
- Update only verified FWH dashboard and contractor setup **visible** names at the owning branch/approved merge point. Preserve JS file/cache/redirect and Auth callback behavior unless Stage 1 explicitly authorized a technical cutover.
- Update README, PROJECT_PROFILE and current-facing documentation to reflect new canonical repo slug while preserving historical commit references and old path evidence. Never globally replace `FPP`: some references mean the original separate app or immutable historical WO numbering.
- Run focused icon/resource and dashboard checks, then complete Android + dashboard CI and Governance Check on the exact final PR head. Merge per current FWH governance.

## Stop conditions and completion evidence

Do not modify FPP; do not perform a repo rename while an unknown Pages/Auth redirect could strand pending invites. No unapproved Level-3 deployment. No replacement Android applicationId or signer. Do not treat a green fake/unit test as a successful real invite redirect. Existing PR #17/#20 retain their own gate status.

Completion requires: canonical repo identity is `timbone72-CC/field-work-hub`; ruleset active and enforced; real Pages URL plus controlled invite redirect tested if active; historical branches/PRs available; FWH Internal installs over its previous package with the approved distinguishable icon; dashboard displays Field Work Hub Admin; the original FPP is untouched. Record each real test and rollout SHA once in a post-change implementation record.
