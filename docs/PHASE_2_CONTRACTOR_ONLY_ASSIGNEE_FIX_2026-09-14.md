# Phase 2 Contractor-Only Assignee Fix — 2026-09-14

## Classification

**Level 3 — authorization/role boundary.**

Observed during the final Phase 2 real-client closure smoke on a Galaxy S22: the Admin dashboard assignee picker returned both the Contractor account and the Admin account.

The approved roadmap says Admin dispatches field work to Contractors. The server must enforce that rule; hiding Admin in dashboard JavaScript alone would be insufficient.

## Evidence / root cause

Current live/repository functions explicitly allowed `role in ('ADMIN', 'CONTRACTOR')` when validating assignment targets:

- `private.admin_list_assignable_users()`
- `private.admin_create_work_order(...)`
- `private.admin_update_work_order(...)`
- `private.respond_reassignment(...)` when an in-progress handoff is accepted

Therefore an Admin could appear as assignable and a modified client could submit an Admin UUID as an assignee even if the UI filtered it.

## Approved behavior being restored

A work-order assignment target must be an active `CONTRACTOR` in the same organization.

This fix does **not**:

- delete or rewrite any existing work order;
- change existing Admin/Contractor Auth identities;
- change organization membership;
- change who may open the Admin dashboard;
- change the existing current-contractor consent requirement for `IN_PROGRESS` handoff;
- change receipt-reset behavior;
- change existing historical/test rows already assigned to an Admin;
- start Phase 3 or introduce run/Room behavior.

The old Admin-only control row may remain as test evidence, but new create/reassign/handoff targets are Contractor-only.

## Runtime change

Forward migration:

`20260915014259_restrict_work_order_assignment_to_contractors.sql`

It replaces only the current private assignment RPC implementations so that:

1. `admin_list_assignable_users()` returns only active same-org Contractors;
2. `admin_create_work_order(...)` rejects any target whose role is not `CONTRACTOR`;
3. `admin_update_work_order(...)` rejects any new/current requested assignee whose role is not `CONTRACTOR`;
4. `respond_reassignment(...)` revalidates a pending target as an active same-org Contractor before accepting the handoff.

Public wrapper signatures, grants, receipt semantics, status transitions, numbering, and dashboard API calls remain unchanged.

No dashboard code change is required because the dashboard already renders the server-provided assignable-user list.

## Protected behavior

- same-organization authorization remains server-side;
- Admin-only privileged dispatch RPCs stay narrow;
- Contractor cannot call the Admin assignable-user list;
- `ASSIGNED` reassignment stays immediate;
- `IN_PROGRESS` reassignment stays consent-required;
- reassignment still clears/resets receipt as already implemented;
- completed/cancelled reassignment remains blocked;
- direct broad table insert/update permissions remain blocked.

## Safe verification plan

Use the Team development Supabase project and disposable Team data only.

After applying the migration:

- confirm live function definitions contain Contractor-only assignment-target checks;
- under Admin JWT context, `admin_list_assignable_users()` returns Contractors and does not return Admins;
- under Admin JWT context, create with an Admin target is rejected;
- valid Contractor target remains accepted (use rollback/disposable data so no lasting test WO is required);
- editing/reassigning a disposable WO to an Admin target is rejected;
- editing/reassigning to the current/valid Contractor remains accepted;
- a crafted pending Admin handoff cannot be accepted by `respond_reassignment`;
- current Contractor receipt/reassignment behavior remains intact;
- Supabase security/performance advisors are checked after DDL;
- final repository diff contains only the impact record + forward migration unless verification proves another owning surface must change;
- complete existing CI runs on the exact final branch head before merge.

The real-phone Phase 2 closure smoke is resumed only after the server boundary passes the automated/live checks.

## Verification evidence

Migration applied successfully to the Team development Supabase project. Live migration history recorded version `20260915014259`, and the repository migration filename was aligned to that exact version.

Controlled JWT-context verification used transaction rollback/disposable state so no test mutation remained afterward.

Results:

- `admin_list_assignable_users()` returned only the same-org `CONTRACTOR`; Admin was absent — **PASS**.
- `admin_create_work_order(...)` with Admin target returned SQLSTATE `42501` — **PASS**.
- `admin_create_work_order(...)` with valid Contractor target succeeded inside rollback transaction — **PASS**.
- `admin_update_work_order(...)` with Admin target returned SQLSTATE `42501` — **PASS**.
- `admin_update_work_order(...)` with valid/current Contractor succeeded inside rollback transaction — **PASS**.
- crafted `IN_PROGRESS` handoff with Admin as pending target was rejected on accept with SQLSTATE `42501` — **PASS**.
- after rollback verification, `TEST-0003-DASHBOARD` remained `ASSIGNED` to the Contractor with its prior receipt intact and no pending reassignment — **PASS**.

Post-DDL advisors:

- Security advisor: existing warning that Supabase Auth leaked-password protection is disabled. This fix does not change Auth password policy and did not introduce the warning.
- Performance advisor: six informational unused-index notices on existing Team indexes. This function-only migration added no index and did not introduce them.

No advisor finding indicates a regression caused by this migration.

Remaining before merge:

- final branch CI on the exact head;
- real Galaxy S22 dashboard check that the assignee picker now shows Contractor-only;
- resume the compact Phase 2 reassignment/receipt closure smoke as far as available contractor accounts permit;
- explicit operator Level-3 pre-merge approval.

## Rollback

Known-good pre-fix repository/runtime baseline: `a400c7449045840dfef6d6d6fef037804be00806`.

Repository rollback: revert the narrow migration/record commit.

If the migration has already been applied to the Team development Supabase project and rollback is required, use a new forward rollback migration restoring the prior target predicate `role in ('ADMIN', 'CONTRACTOR')` in the four affected private functions. Do not rewrite migration history.

No rollback step may delete existing WOs or assignment evidence.

## Merge gate

Because this is Level 3, **explicit operator approval is required before merge** after the exact final diff and verification evidence are available.
