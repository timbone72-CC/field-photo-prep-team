-- Narrow Phase 3A advisor repair; preserve all run/history data and access semantics.
create index work_orders_current_run_id_id_idx
  on public.work_orders(current_run_id, id);
create index photos_run_id_work_order_id_idx
  on public.photos(run_id, work_order_id);
-- Superseded by the covering composite index.
drop index public.photos_run_id_idx;

alter policy work_order_runs_select_allowed on public.work_order_runs
using (
  organization_id = nullif(((select auth.jwt()) -> 'app_metadata' ->> 'organization_id'), '')::uuid
  and (
    ((select auth.jwt()) -> 'app_metadata' ->> 'role') = 'ADMIN'
    or current_assignee_user_id = (select auth.uid())
  )
);
alter policy work_order_assignments_select_allowed on public.work_order_assignments
using (
  organization_id = nullif(((select auth.jwt()) -> 'app_metadata' ->> 'organization_id'), '')::uuid
  and (
    ((select auth.jwt()) -> 'app_metadata' ->> 'role') = 'ADMIN'
    or assigned_user_id = (select auth.uid())
  )
);
alter policy photos_contractor_insert_waiting on public.photos
with check (
  captured_by = (select auth.uid())
  and sync_status = 'WAITING'
  and remote_file_id is null
  and uploaded_at is null
  and exists (
    select 1 from public.work_orders wo
    where wo.id = photos.work_order_id
      and wo.current_run_id = photos.run_id
      and wo.organization_id = nullif(((select auth.jwt()) -> 'app_metadata' ->> 'organization_id'), '')::uuid
      and wo.assigned_user_id = (select auth.uid())
      and wo.field_status <> 'CANCELLED'
  )
);
