drop policy if exists organizations_select_own on public.organizations;
create policy organizations_select_own
on public.organizations
for select
to authenticated
using (
  id = nullif(((select auth.jwt()) -> 'app_metadata' ->> 'organization_id'), '')::uuid
);

drop policy if exists work_orders_select_allowed on public.work_orders;
create policy work_orders_select_allowed
on public.work_orders
for select
to authenticated
using (
  organization_id = nullif(((select auth.jwt()) -> 'app_metadata' ->> 'organization_id'), '')::uuid
  and (
    ((select auth.jwt()) -> 'app_metadata' ->> 'role') = 'ADMIN'
    or assigned_user_id = (select auth.uid())
  )
);

drop policy if exists work_orders_admin_insert on public.work_orders;
create policy work_orders_admin_insert
on public.work_orders
for insert
to authenticated
with check (
  ((select auth.jwt()) -> 'app_metadata' ->> 'role') = 'ADMIN'
  and organization_id = nullif(((select auth.jwt()) -> 'app_metadata' ->> 'organization_id'), '')::uuid
);

drop policy if exists work_orders_admin_update on public.work_orders;
create policy work_orders_admin_update
on public.work_orders
for update
to authenticated
using (
  ((select auth.jwt()) -> 'app_metadata' ->> 'role') = 'ADMIN'
  and organization_id = nullif(((select auth.jwt()) -> 'app_metadata' ->> 'organization_id'), '')::uuid
)
with check (
  ((select auth.jwt()) -> 'app_metadata' ->> 'role') = 'ADMIN'
  and organization_id = nullif(((select auth.jwt()) -> 'app_metadata' ->> 'organization_id'), '')::uuid
);

drop policy if exists photos_select_allowed on public.photos;
create policy photos_select_allowed
on public.photos
for select
to authenticated
using (
  exists (
    select 1
    from public.work_orders wo
    where wo.id = photos.work_order_id
      and wo.organization_id = nullif(((select auth.jwt()) -> 'app_metadata' ->> 'organization_id'), '')::uuid
      and (
        ((select auth.jwt()) -> 'app_metadata' ->> 'role') = 'ADMIN'
        or wo.assigned_user_id = (select auth.uid())
        or photos.captured_by = (select auth.uid())
      )
  )
);

drop policy if exists photos_contractor_insert_waiting on public.photos;
create policy photos_contractor_insert_waiting
on public.photos
for insert
to authenticated
with check (
  captured_by = (select auth.uid())
  and sync_status = 'WAITING'
  and remote_file_id is null
  and uploaded_at is null
  and exists (
    select 1
    from public.work_orders wo
    where wo.id = photos.work_order_id
      and wo.organization_id = nullif(((select auth.jwt()) -> 'app_metadata' ->> 'organization_id'), '')::uuid
      and wo.assigned_user_id = (select auth.uid())
      and wo.field_status <> 'CANCELLED'
  )
);
