# Contractor Manual Setup Link — 2026-09-21

## Classification

**Level 3 — Supabase Auth / Contractor onboarding.**

Approved operator request: replace email-dependent contractor invitations with a secure setup link that the Admin can copy and share directly.

Branch: `feat/contractor-manual-setup-link`

Known-good rollback baseline: `0c657182443d09f86c7e23872458f457016468c2`

## Problem

The existing Admin Add Contractor workflow reserves seats correctly and the trusted Edge Function owns Auth-admin work, but Supabase's built-in SMTP refuses delivery to ordinary contractor email addresses that are not pre-authorized project-team addresses.

The operator does not want Gmail SMTP / 2-step-verification setup.

## User-visible workflow

`Admin signs in → enters contractor name + email → Team reserves a seat → trusted backend generates a Supabase invite action link without sending email → Admin copies the setup link and shares it directly → contractor opens it → contractor chooses their own password → Team activates the invitation → contractor becomes assignable and can sign into Android`

## Protected behavior

- Admin never chooses, receives, stores, or displays the contractor password.
- Service-role/secret credentials remain only in the trusted Edge Function.
- The dashboard receives only the generated one-time setup URL for the invitation it just created.
- The setup URL is not written to Postgres, localStorage, or sessionStorage.
- Existing server seat limits, organization metadata, CONTRACTOR role assignment, pending-seat reservation, activation, assignability, and cancellation remain authoritative.
- Existing internal `SENT` invitation status is retained to avoid a schema migration; for this workflow it means an Auth setup credential was issued, not that an email was delivered.
- Existing failed historical invitation rows remain unchanged.

## Implementation

### Trusted Edge Function

Replace `auth.admin.inviteUserByEmail()` with `auth.admin.generateLink({ type: 'invite', ... })`.

Current Supabase documentation states that `generateLink` generates an invite action link without sending it and creates the Auth user for invite flows. The call remains inside the service-role Edge Function.

The generated invite includes:

- contractor email;
- display name in user metadata;
- immutable Team invitation UUID marker in user metadata;
- the existing Contractor setup-page redirect.

After Auth user creation:

1. server-controlled `app_metadata.role = CONTRACTOR`;
2. server-controlled `app_metadata.organization_id`;
3. existing invitation finalization marks the reserved invitation `SENT`;
4. the Edge Function returns the setup URL to the authenticated Admin request.

If Auth user creation succeeds but a usable setup URL cannot be proven, the invitation fails closed as `PROBLEM`; it is not reported as ready.

### Admin dashboard

After successful creation:

- show **Setup link ready**;
- show the exact setup URL in a read-only field;
- provide **Copy Setup Link**;
- warn that anyone holding the link can use it until it expires / is consumed;
- do not persist the link;
- clear the displayed link on Admin sign-out or when starting another invitation.

### Contractor setup page

Keep the existing Supabase invite-session password setup and activation path. Change only email-specific wording so it refers to the setup link shared by the Admin.

## Failure handling

- No seat available → no Auth user/link generation.
- Invalid Admin/session/org → no Auth user/link generation.
- Generate-link known failure with no Auth user → reservation becomes `FAILED`.
- Auth identity exists but link outcome cannot be proven → reservation becomes `PROBLEM`, seat remains fail-closed.
- Lost/expired setup link is not silently recreated by the browser. The pending invitation can be cancelled using the existing safe cancellation path and a new invitation created.
- Link copy failure leaves the URL visible for manual copy.
- Activation remains impossible until the contractor actually opens the valid Supabase invite link and sets a password.

## Verification

Automated:

- dashboard JavaScript syntax;
- no client/service-role secret leakage;
- Edge Function uses `generateLink`, not `inviteUserByEmail`;
- invite link remains server-generated and is returned only from the authenticated Edge Function;
- dashboard exposes Copy Setup Link and does not persist it in browser storage;
- existing cancellation and activation markers remain;
- complete dashboard and Android CI on exact final head.

Provider reality gate:

1. deploy the exact Edge Function candidate;
2. Admin creates a disposable second Contractor through the dashboard;
3. Admin receives a setup URL without SMTP/email delivery;
4. copy/open link in a normal browser;
5. contractor sets own password;
6. invitation becomes `ACCEPTED`;
7. contractor becomes assignable;
8. contractor signs into Android;
9. use the second Contractor to complete the remaining Phase 2 reassignment/receipt smoke.

## Rollback

Repository: revert this PR to `0c657182443d09f86c7e23872458f457016468c2`.

Edge Function: redeploy the prior `admin-invite-contractor` function version if provider behavior contradicts the plan.

No database migration is required for this slice. Existing invitation rows and seat evidence are preserved.

## Merge gate

Do not merge until:

- exact-head CI is green;
- live Edge Function/provider reality check passes;
- no unexpected Auth/seat/cancellation regression is found;
- operator gives the required explicit Level-3 pre-merge approval.
