# Phase 2 Dispatch Gate — 2026-09-13

## Result

**PASSED**

The first real Admin-dashboard-to-Contractor-Android dispatch path was verified end to end using disposable Team test work.

## Verified flow

1. Admin signed into the hosted Field Photo Prep Team dashboard through Supabase Auth.
2. The dashboard loaded assignable Team users from a server-authorized RPC rather than hard-coded user IDs or emails.
3. Admin created `TEST-0003-DASHBOARD` from the hosted dashboard and assigned it to the Contractor account.
4. Supabase stored the work order as `ASSIGNED` in the correct Team organization and bound it to the Contractor Auth UUID.
5. The existing Team Android client signed in as the Contractor and fetched work orders without a client-side assignee filter.
6. Supabase RLS returned both Contractor-visible work orders: `TEST-0001` and `TEST-0003-DASHBOARD`.
7. The Admin-only control work order `TEST-0002-ADMIN-ONLY` remained hidden from the Contractor.

## Security/hardening verified during this slice

- generic authenticated INSERT access to `public.work_orders` was removed;
- Admin work-order creation uses the narrow `admin_create_work_order` server action;
- the server validates that the assignee is an active Team user in the same organization;
- an invalid/out-of-organization assignee is rejected;
- Contractor access to the Admin assignable-user list is denied;
- direct table INSERT bypass is blocked;
- the live Supabase migration is mirrored in `supabase/migrations/`;
- dashboard and Android CI both passed before merge;
- GitHub Pages now uses versioned dashboard asset URLs to prevent old JavaScript from being mixed with a newly deployed page.

## Phase status

The **Phase 2 create-and-assign gate is satisfied**.

Phase 2 itself remains open only for the remaining roadmap dispatch controls that have not yet been implemented: **edit an existing work order and reassign an existing work order**. Those should be built as narrow server-authorized Admin actions rather than broad client table updates.
