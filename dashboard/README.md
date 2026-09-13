# Phase 1 Admin Dashboard Gate

This folder is a deliberately small browser client used to prove the Team Admin authentication and RLS boundary before the full admin workflow is built.

It uses only the Supabase project URL and publishable key. The browser session token is held in memory only for this gate. Passwords are never stored by the app.

The work-order request intentionally sends no organization or assignee filter. Supabase RLS must return the allowed rows.

Expected Admin gate result:
- the two disposable Team-organization control work orders are visible;
- the disposable other-organization control work order is absent;
- the page displays `RLS CHECK: PASS`.

This is not the finished Phase 2 dispatch dashboard.
