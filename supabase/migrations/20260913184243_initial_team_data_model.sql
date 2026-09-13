create table public.organizations (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  created_at timestamptz not null default now()
);

create table public.work_orders (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete restrict,
  assigned_user_id uuid references auth.users(id) on delete set null,
  wo_number text not null,
  property_address text not null,
  work_type text not null,
  instructions text,
  due_date date not null,
  field_status text not null default 'ASSIGNED'
    check (field_status in ('ASSIGNED', 'IN_PROGRESS', 'FIELD_COMPLETE', 'CANCELLED')),
  started_at timestamptz,
  field_completed_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.photos (
  id uuid primary key,
  work_order_id uuid not null references public.work_orders(id) on delete restrict,
  captured_by uuid not null references auth.users(id) on delete restrict,
  captured_at timestamptz not null,
  sync_status text not null default 'WAITING'
    check (sync_status in ('WAITING', 'UPLOADING', 'UPLOADED', 'FAILED', 'UNCERTAIN')),
  sha256 text,
  byte_size bigint check (byte_size is null or byte_size >= 0),
  remote_file_id text unique,
  uploaded_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index work_orders_organization_id_idx on public.work_orders (organization_id);
create index work_orders_assigned_user_id_idx on public.work_orders (assigned_user_id);
create index work_orders_due_date_idx on public.work_orders (due_date);
create index photos_work_order_id_idx on public.photos (work_order_id);
create index photos_captured_by_idx on public.photos (captured_by);
create index photos_sync_status_idx on public.photos (sync_status);

create or replace function public.set_updated_at()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create trigger work_orders_set_updated_at
before update on public.work_orders
for each row execute function public.set_updated_at();

create trigger photos_set_updated_at
before update on public.photos
for each row execute function public.set_updated_at();

alter table public.organizations enable row level security;
alter table public.work_orders enable row level security;
alter table public.photos enable row level security;

revoke all on public.organizations from anon;
revoke all on public.work_orders from anon;
revoke all on public.photos from anon;

revoke all on public.organizations from authenticated;
revoke all on public.work_orders from authenticated;
revoke all on public.photos from authenticated;

grant select on public.organizations to authenticated;
grant select, insert, update on public.work_orders to authenticated;
grant select, insert on public.photos to authenticated;

grant all on public.organizations to service_role;
grant all on public.work_orders to service_role;
grant all on public.photos to service_role;

create policy organizations_select_own
on public.organizations
for select
to authenticated
using (
  id = nullif((select auth.jwt() -> 'app_metadata' ->> 'organization_id'), '')::uuid
);

create policy work_orders_select_allowed
on public.work_orders
for select
to authenticated
using (
  organization_id = nullif((select auth.jwt() -> 'app_metadata' ->> 'organization_id'), '')::uuid
  and (
    (select auth.jwt() -> 'app_metadata' ->> 'role') = 'ADMIN'
    or assigned_user_id = (select auth.uid())
  )
);

create policy work_orders_admin_insert
on public.work_orders
for insert
to authenticated
with check (
  (select auth.jwt() -> 'app_metadata' ->> 'role') = 'ADMIN'
  and organization_id = nullif((select auth.jwt() -> 'app_metadata' ->> 'organization_id'), '')::uuid
);

create policy work_orders_admin_update
on public.work_orders
for update
to authenticated
using (
  (select auth.jwt() -> 'app_metadata' ->> 'role') = 'ADMIN'
  and organization_id = nullif((select auth.jwt() -> 'app_metadata' ->> 'organization_id'), '')::uuid
)
with check (
  (select auth.jwt() -> 'app_metadata' ->> 'role') = 'ADMIN'
  and organization_id = nullif((select auth.jwt() -> 'app_metadata' ->> 'organization_id'), '')::uuid
);

create policy photos_select_allowed
on public.photos
for select
to authenticated
using (
  exists (
    select 1
    from public.work_orders wo
    where wo.id = photos.work_order_id
      and wo.organization_id = nullif((select auth.jwt() -> 'app_metadata' ->> 'organization_id'), '')::uuid
      and (
        (select auth.jwt() -> 'app_metadata' ->> 'role') = 'ADMIN'
        or wo.assigned_user_id = (select auth.uid())
        or photos.captured_by = (select auth.uid())
      )
  )
);

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
      and wo.organization_id = nullif((select auth.jwt() -> 'app_metadata' ->> 'organization_id'), '')::uuid
      and wo.assigned_user_id = (select auth.uid())
      and wo.field_status <> 'CANCELLED'
  )
);
