# Field Work Hub — Project Profile

## Product and identifiers

**Field Work Hub (FWH)** is the multi-user work-order dispatch, offline contractor fieldwork and protected evidence-delivery system. The office uses **Field Work Hub Admin**; contractors use an independently installed Android client. This approved product display name does not by itself rename technical identities.

- Authoritative FWH repository: timbone72-CC/field-work-hub (renamed from the historical field-photo-prep-team slug; same repository identity).
- Distinct read-only reference: timbone72-CC/field-photo-prep, the original single-user Field Photo Prep app.
- Current internal Android package and stable test signer remain unchanged until a separately approved technical-identity change.
- The Field Work Hub rename plan is tracked separately from governance and active product phases.

## Authoritative systems

**GitHub:** completed FWH main; each in-progress scope's one authoritative branch/PR and durable record. Onboarding PR #20, Admin automatic refresh PR #27 and the repository/redirect cutover PR #28 are merged. The new-address setup activation test is explicitly deferred until the next Contractor onboarding because both seats are occupied. Phase 3A PR #17 owns the completed run/Room/session work; its database, automated and phone gates passed and explicit merge approval was recorded on 2026-10-02. Recheck PR #17 for its final integration result; do not restart that implementation line.

**Team Supabase/Auth:** authenticated user and server-controlled organization/role, seat/invitation lifecycle, server-approved current assignment/reassignment, work-order and run identity, accepted field state and synchronized metadata. Enforce RLS and narrow server-authorized operations. Never ship elevated keys to clients.

**Android local persistence:** the verified Phase 3A Room implementation is authoritative for which exact authenticated user's assignments and pending local evidence have durably reached this device. Use PR #17’s actual merge state to distinguish the tested internal candidate from integration on main. Local pending work/photos are not proof of server acceptance.

**Company-controlled HNP Google Drive:** authoritative for exact confirmed remote objects/folder IDs. First-version contractor access is **server-mediated**: contractor phones do not acquire the company's reusable Drive credentials or use FPP's per-device SAF folder-picker model. Supabase remains authoritative for Team business and assignment state.

## Protected invariants

- Team/FPP repository, package, backend and field-data separation is absolute for routine FWH work.
- Contractor/admin and cross-organization isolation are enforced on the server, not the UI.
- Stable UUIDs identify organization, user, Team work order, field run and photo; display names/addresses and existing FPP-prefixed WO number strings are not identities.
- Reassignment or cancellation never silently destroys offline-started work or unconfirmed photos; server authorization and approved consent remain authoritative.
- Permanent photo UUID and protected original precede capture; prepared derivative is separate.
- Stored photo/run/work-order binding and approved remote destination never follow current screen selection or visible folder name.
- An ambiguous remote outcome stops blind retry; confirm exact remote identity before durable success and cleanup.
- Company storage permissions and secrets do not move to contractor Android clients.
- Preserve established work screens, understandable operator labels and phase-gated behavior; do not add unapproved UI or future hooks.

## External-state parity and environment isolation

When modified, reconcile Team Supabase migration order/RLS/RPC/Edge Functions/redirect allowlists, dashboard deployment, Android package and signing settings, CI configuration and any company storage authorization. Live customer work is not a disposable test surface. Use independent safe fixtures; record real provider/device limitations accurately.

This repository is public: no real customer/contractor PII, live HNP photos, secrets, refresh tokens, service-role credentials, signing material or recovery codes in source or PR metadata.

## Detailed rule owners

- Universal workflow, takeover, continuity and closeout: GOVERNANCE.md.
- Risk classification, approval, rollback: CHANGE_CONTROL_CONTRACT.md.
- Approved product behavior, phases and completion: docs/ROADMAP.md.
- Test selection and truthful reporting: TESTING_CONTRACT.md.
- Server/Room/Drive/photo/authorization system boundaries: INTEGRATION_CONTRACT.md.
- Device/external staging: docs/PHASE_STAGING_DOCTRINE.md.
- FWH-specific active designs, impact records and build-state: the scope's authoritative documentation.
- Work-surface rule routing: RULE_INDEX.md.

FPP's SAF provider rules, FPP backend identity configuration and single-user UI flows are **not** FWH rules merely because their governance pattern is proven.
