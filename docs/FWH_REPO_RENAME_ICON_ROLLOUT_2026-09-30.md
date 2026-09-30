# Field Work Hub — Repository Rename and Approved App Icon Rollout

Recorded: 2026-09-30  
Request: Rename the **separate Team repository** from `timbone72-CC/field-photo-prep-team` to **`timbone72-CC/field-work-hub`**; adopt the operator-approved FWH hub/network icon so Android users cannot confuse FWH with the original Field Photo Prep (FPP).  
This document: **Level 1 planning and status record**. It does not perform the GitHub rename, deploy links or change an APK. The execution steps below must observe their own risk/approval gates.

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

## Stage 1 checkpoint — 2026-09-30

Historical preflight checkpoint; the later URL configuration checkpoint below supersedes its browser-access handoff and unknown hosted URL settings.

### Classification and authoritative lines

Goal: verify the existing contractor setup workflow and prepare the new address before renaming. This checkpoint is a **Level 1 documentation update**, scope key `docs-fwh-pre-rename-setup-evidence`, branch `docs/fwh-pre-rename-setup-evidence`, from governed main `f8491f4d58f5fb694c15b55bb1c739cfc251e913`. Rollback: revert only this document update. Required packs: AGENTS, GOVERNANCE, PROJECT_PROFILE, RULE_INDEX, CHANGE_CONTROL, TESTING, INTEGRATION, approved roadmap contractor lifecycle/Phase 2/Phase 8B, phase-staging doctrine and PR #20's setup-link implementation record.

PR #20 remains the sole Level 3 onboarding implementation line, `feat/contractor-manual-setup-link-backend`, head `c7938e900261471a8102fd491c30a539934a05ca`. PR #17 remains independent. No Android, dashboard, Edge Function source, Auth configuration, seat limit or repository name was changed by this checkpoint.

### Verified provider and GitHub state

- Team Supabase `vyocaujuwrivoqynvitm` was observed `INACTIVE`. It was resumed to perform the requested verification and then confirmed `ACTIVE_HEALTHY`; existing invitation schema and records were readable after restoration. No project was created, plan upgraded or migration applied. The separate original FPP project was untouched.
- Deployed `admin-invite-contractor` **version 3**, JWT verification **true**, has byte-for-byte identical `index.ts` to PR #20's exact head (source blob `a8055b75768c88ef98dddd7dc7921b61c6786cb0`). Deployment is therefore already present despite PR #20's older pending-deployment wording. No redeployment was needed or performed.
- Exact PR #20 head has successful `build` and `dashboard` checks: Actions runs `35673493268` and `35673493265`. This is automated evidence, not a passed real contractor setup.
- Latest successful Pages deployment: [run 35673348937](https://github.com/timbone72-CC/field-photo-prep-team/actions/runs/35673348937), source `7f495ba06d5d3c6f7761416034708c158b7875d9`. Its deploy-job log reports `https://timbone72-cc.github.io/field-photo-prep-team/`. Comparison to current main shows no subsequent `dashboard/**` or `pages.yml` changes. This proves the deployed revision/URL, not current browser reachability or successful invitation activation.
- Live ruleset `24245891`, **FWH Main Protection**, is active on the default branch, has no bypass actors, requires a PR and resolved discussions, blocks deletion/force push, and requires the GitHub Actions contexts **governance**, **build**, **dashboard** (integration ID `15368`).
- Read-only invitation check at **2026-09-30T13:40:45Z**: 1 `CANCELLED`, 4 `FAILED`; **0** `RESERVED/SENT/PROBLEM/CANCELLING`; **0** pending rows with confirmed Auth identities; **0** unconfirmed Auth accounts carrying a Team invitation marker. No current tracked pending invitation needs the old path. Recheck immediately before rename; any new setup test creates a fresh dependency until completed.
- `timbone72-CC/field-work-hub` currently returns repository-not-found. This is not a reservation or proof GitHub's rename form will accept the name.

### Prepared address mapping — not yet applied

| Surface | Current | Proposed after rename |
| --- | --- | --- |
| Repository | `https://github.com/timbone72-CC/field-photo-prep-team` | `https://github.com/timbone72-CC/field-work-hub` |
| Admin Pages | `https://timbone72-cc.github.io/field-photo-prep-team/` | `https://timbone72-cc.github.io/field-work-hub/` |
| Contractor setup redirect | `https://timbone72-cc.github.io/field-photo-prep-team/contractor-invite.html` | `https://timbone72-cc.github.io/field-work-hub/contractor-invite.html` |

At this preflight checkpoint, the proposed Pages addresses were **not live or confirmed allowlisted**. The Edge Function supports `TEAM_INVITE_REDIRECT_URL`, but the connector cannot read its configured value or the hosted Auth Site URL/additional redirect list. Do not infer the effective live redirect from the source fallback alone. Public-page retrieval was unavailable through the search tool; that result is not an HTTP 404 or a failed setup test.

### Narrow Level 3 cutover plan for the next gate

1. Inspect Team's hosted Auth URL configuration and the effective invitation redirect. Record only these non-secret URL values. Preserve every existing unrelated callback; do not copy the original FPP project's settings.
2. Preauthorize the **exact proposed contractor setup URL** while retaining the current allowed setup URL. Keep the effective invite destination on the old working path until the new page is deployed and verified. This is preparation, not a premature cutover.
3. Complete PR #20's existing real gate on the current site: Admin creates/copies one setup link for an operator-controlled disposable second Contractor, that Contractor chooses their own password, activation reports `ACCEPTED`, Admin can assign them, and Android sign-in succeeds. Never send an email automatically or save the credential-bearing link/password in source, PRs or browser storage. Preserve the remaining Phase 2 reassignment/receipt gate and explicit Level 3 merge approval.
4. Before rename, recheck pending invitation/Auth counts and pause new invitation issuance for the cutover. Finish legitimate pending setups first. Do not assume timestamp age proves expiration or cancel a used identity. A remaining unresolved/confirmed-but-unactivated setup blocks rename.
5. After operator approval of this concrete hosting/Auth cutover, rename the same repository, deploy Pages at the new path, and verify both Admin and setup assets. Then change the explicit Team invitation redirect to the proposed setup URL and reconcile PR #20's fallback in its owning implementation line. If the Site URL uses the old Admin path, change it to the new Admin URL at this same verified cutover. Keep the Pages CORS origin `https://timbone72-cc.github.io` unchanged.
6. Verify a real newly issued setup link targets the new page and activates correctly, then verify preserved repository ID `1368673158`, history/PRs/branches/ruleset/checks and update the developer clone's origin. For a failed cutover, stop issuance, restore prior Team URL settings and old repository/Pages path, redeploy the previously verified dashboard revision, and retest before use. Renaming back alone is not evidence of recovery.

GitHub's [rename documentation](https://docs.github.com/en/repositories/creating-and-managing-repositories/renaming-a-repository) explicitly excludes project-site URLs from repository redirects. Supabase's [redirect documentation](https://supabase.com/docs/guides/auth/redirect-urls) requires the requested redirect to match the configured allowed URLs.

### Preflight handoff — superseded by the checkpoint below

**Status: preflight evidence recorded; end-to-end setup and live URL preparation still BLOCKED on browser/provider access.** The backend resume and deployed-source parity are PASS. The current link's effective destination, hosted Auth allowlist, new URL preauthorization, real second-Contractor activation/Android sign-in and remaining Phase 2 smoke are not claimed as passed.

Next action: obtain approval for browser fallback because the connectors do not expose the hosted redirect settings, then inspect Team's current settings and perform only the preparation above before the repository rename. Do not rename, switch the effective redirect early, merge PR #20/#17, or incorporate the icon at this checkpoint.

## URL configuration checkpoint — 2026-09-30

### Classification and evidence boundary

Goal: record Team URL preparation and the next real setup-link gate. This is a **Level 1 documentation update**, scope key `docs-fwh-url-configuration-evidence`, authoritative branch `docs/fwh-url-configuration-checkpoint`, from main `8ea300a3ef43f8f65bf43699ebad7dbdc992b588`. Required packs: AGENTS, GOVERNANCE, PROJECT_PROFILE, RULE_INDEX, CHANGE_CONTROL, TESTING, INTEGRATION, contractor lifecycle/Phase 2/Phase 8 of the approved roadmap, phase-staging doctrine and PR #20's implementation record. Only this rollout record changes in Git; rollback is a narrow revert of this documentation update.

The Auth/hosting preparation remains part of the existing Level 3 rollout plan. Browser fallback was approved, and the operator reported completing manual Supabase portal sign-in. Browser control and uploaded-screenshot access then became unavailable. The hosted configuration below is **operator-reported save/list evidence**, not an independent authenticated browser/API readback or a passed invite activation.

### Team settings reported by the operator

Project: `vyocaujuwrivoqynvitm`. The operator supplied its exact Auth URL Configuration page, reported Site URL `http://localhost:3000`, and reported an empty Redirect URLs list.

| Setting | Reported saved value |
| --- | --- |
| Site URL | `https://timbone72-cc.github.io/field-photo-prep-team/` |
| Additional redirect — existing setup page | `https://timbone72-cc.github.io/field-photo-prep-team/contractor-invite.html` |
| Additional redirect — prepared FWH setup page | `https://timbone72-cc.github.io/field-work-hub/contractor-invite.html` |

The operator confirmed both separate redirect entries appeared at **2026-09-30T18:31:19Z** and confirmed saving the current Admin Site URL at **2026-09-30T18:34:59Z**. The new setup URL is preauthorized by that report; its new Pages path has not been deployed or tested. The effective `TEAM_INVITE_REDIRECT_URL` remains unverified. No Edge Function source/environment, repository name, Android package/signer, role/org/seat rule or original FPP surface was changed by this checkpoint.

Earlier in this session, the current public contractor setup page rendered its valid-link-required guard when opened without a setup credential. That proves the existing asset loads and handles a missing link; it does not prove a real invite redirect, password setup or activation.

### Current handoff and rollback

PR #20 remains open/draft/unmerged at `c7938e900261471a8102fd491c30a539934a05ca`, on `feat/contractor-manual-setup-link-backend`, and remains the sole onboarding implementation line. PR #17 is independent. The repository remains `timbone72-CC/field-photo-prep-team`, stable ID `1368673158`.

Next gate: open the existing live Admin page, sign in as the existing Team Admin, and use one operator-controlled disposable second Contractor account through PR #20's existing workflow. Verify newly issued link delivery without SMTP, its actual redirect to the current setup page, contractor-chosen password, `ACCEPTED`, assignability and Android sign-in; then retain the remaining Phase 2 reassignment/receipt smoke. Stop on an unexpected redirect, Auth/seat result or missing controlled test identity. Store no test email, credential-bearing link or password in this public record. Real setup and Android gates remain **PENDING**.

Keep the effective invite destination on the current path until the renamed Pages site is deployed and verified. Before rename, independently reconcile hosted settings/effective redirect when access returns, recheck unresolved invitation/Auth counts, and obtain explicit approval for the concrete Level 3 cutover. PR #20 merge approval remains pending.

For configuration rollback, pause new link issuance and reconcile any links issued since preparation before restoring the recorded prior Site URL `http://localhost:3000` and empty additional list; those prior values are evidence, not a known-working production setup. Do not delete Auth identities or invitation rows as part of this URL rollback. For the later repository/Pages cutover, use the original narrow cutover rollback above and verify recovery through a real link.
