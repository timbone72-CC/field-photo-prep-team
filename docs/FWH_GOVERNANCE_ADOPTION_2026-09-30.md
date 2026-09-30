# Field Work Hub — Proven FPP Governance Adoption

Date: 2026-09-30  
Scope key: governance-fwh-proven-controls  
Classification: Level 2 because GitHub Actions enforcement is changed; document and PR-template edits alone would be lower risk.  
Authoritative line: governance/fwh-proven-controls; base/rollback: main at 7f495ba06d5d3c6f7761416034708c158b7875d9.  
Original FPP: read-only source of proven governance practice.

## Evidence-based comparison and scope

FWH already has meaningful AGENTS.md, CHANGE_CONTROL_CONTRACT.md, TESTING_CONTRACT.md, INTEGRATION_CONTRACT.md, staging doctrine and approved roadmap. Do **not** replace its product rules with FPP's single-user SAF/Drive contract or restart existing product phases.

FPP currently adds four valuable universal controls: a short AGENTS entry point, GOVERNANCE.md (one authoritative line/external parity/handoff), PROJECT_PROFILE.md (exact systems/immutable project boundary), and RULE_INDEX.md (select the smallest relevant detailed contracts). This change adapts these three documents and shortens AGENTS while preserving all existing FWH-specific contract and roadmap authority.

FPP's machine-checkable GitHub governance also adds: a structured pull-request template, stable scope key, PR branch/classification checks, duplicate declared scope detection, minimum risk levels for obvious high-risk paths, and an honest distinction between a recorded approval field and real operator approval. Add the proven check to FWH with Team-appropriate wording and sensitive paths.

## Protected behavior

No Android, dashboard, Supabase, Room, migration, Drive, signing, production, hosting or original FPP runtime changes. No updates to FWH current roadmap phases, technical app identity, company Drive root, or the separate Field Work Hub rename PR. Existing draft PR #17 (Phase 3A) and draft PR #20 (manual contractor setup) keep their existing physical/provider and explicit operator approval gates; neither is merged by this change.

The governance check MUST NOT execute or check out untrusted pull-request code under pull_request_target. It reads PR event metadata and GitHub's read-only API with limited permissions. It validates declared facts, not genuine consent or backend parity.

## Implementation slices in this one PR

1. Add Team-adapted GOVERNANCE.md, PROJECT_PROFILE.md and RULE_INDEX.md; replace verbose AGENTS.md with a short mandatory entry preserving original-FPP isolation, phase stops and Level-3 approval.
2. Add a PR template mirroring the existing FPP classification. Adapt the proven event-based governance check. Keep the existing Android and dashboard CI workflows untouched to avoid adding unrelated runtime gates in this PR.
3. Inspect every changed file; check no real FPP path is written and no FWH product code/database/provider configuration changes. Check workflow syntax/required fields and verify existing Android+dashboard CI on the final PR head. Because pull_request_target loads the base workflow, the new check is **staged** until it lands on main, not claimed active from this PR's own run.

## Safe activation and existing PRs

Before declaring this check enforceable, populate accurate structured governance classifications on existing open PRs, including the unmerged rename documentation PR, draft Phase 3A and draft setup-link PR. Keep Level-3 approval PENDING until the operator actually approves *each exact scope* at its required pre-merge gate. Do not rewrite their tests or claim live gates passed by adding metadata.

After the governance PR is reviewed/merged, verify the actual Governance Check runs against PR events and preserve the two existing CI job names. Add branch protection only via authorized repository-admin action after checking live settings:
- require PR to merge into main and require the **Governance Check / governance**, **Android Team Client CI / build**, and **Admin Dashboard Gate CI / dashboard** checks once names and branch coverage have been confirmed;
- require conversation resolution if supported;
- block force push and branch deletion, including owner bypass when supported;
- do **not** invent another approving human reviewer, signed-commit requirement, or unnecessary up-to-date restriction.

The connected GitHub change workflow cannot substitute for verifying/enabling actual repository-admin branch protection. A passing workflow without required status checks is advisory and must not be represented as a hard merge barrier.

## Verification, stop and rollback

A workflow-file change is Level 2 even though no product runtime should change. Perform diff and static check review, plus the existing PR-triggered Android/dashboard CI on the exact final head. When the check is merged, prove one valid classification passes and a deliberately invalid/duplicate classification fails without using live work/customer data. Do not merge or declare enforcement if required CI fails or an existing draft's governance state would be misrepresented.

Rollback: revert the narrow governance PR from main; restore AGENTS.md and remove only this scope's newly introduced governance/template/workflow files. Do not alter open runtime PR contents, live provider data, package identity, or FPP. Document activation results before claiming completion.

## Deferred improvements — not part of this PR

FPP's Markdown-only Android CI optimization is also useful to FWH, but FWH has **two** separate CI workflows. Adapt their skip logic in a separate narrow verified change after the governance baseline is proven, retaining stable required check job names for both Android and dashboard. Do not copy FPP's release/signer-specific tests or FPP's SAF photo-provider test packs into FWH.
