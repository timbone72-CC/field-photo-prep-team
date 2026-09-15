-- Phase 3A draft only.
-- This file is intentionally NOT under supabase/migrations/ yet.
-- Apply through the governed Supabase migration gate, then mirror the exact
-- applied migration version into supabase/migrations/.

alter table public.work_orders
  add column current_run_id uuid,
  add column current_run_sequence integer not null default 1
    check (current_run_sequence > 0);

create table public.work_order_runs (
  id uuid primary key default gen_random_uuid(),
  work_order_id uuid not null references public.work_orders(id) on delete restrict,
  organization_id uuid not null references public.organizations(id) on delete restrict,
  run_sequence integer not null check (run_sequence > 0),
  current_assignee_user_id uuid references auth.users(id) on delete restrict,
  field_status text not null
    check (field_status in ('ASSIGNED', 'IN_PROGRESS', 'FIELD_COMPLETE', 'CANCELLED')),
  assignment_received_at timestamptz,
  started_at timestamptz,
  field_completed_at timestamptz,
  requirement_snapshot jsonb not null default '{}'::jsonb
    check (jsonb_typeof(requirement_snapshot) = 'object'),
  reopen_reason text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  closed_at timestamptz,
  unique (work_order_id, run_sequence),
  unique (id, work_order_id)
);

create table public.work_order_assignments (
  id uuid primary key default gen_random_uuid(),
  run_id uuid not null references public.work_order_runs(id) on delete restrict,
  organization_id uuid not null references public.organizations(id) on delete restrict,
  assigned_user_id uuid not null references auth.users(id) on delete restrict,
  assignment_started_at timestamptz not null,
  assignment_received_at timestamptz,
  assignment_ended_at timestamptz,
  end_reason text check (
    end_reason is null
    or end_reason in ('REASSIGNED', 'HANDOFF', 'CANCELLED', 'FIELD_COMPLETE', 'ADMIN_ACTION')
  ),
  created_at timestamptz not null default now(),
  check (
    (assignment_ended_at is null and end_reason is null)
    or (assignment_ended_at is not null and end_reason is not null)
  )
);

create index work_order_runs_work_order_id_idx
  on public.work_order_runs(work_order_id);
create index work_order_runs_organization_id_idx
  on public.work_order_runs(organization_id);
create index work_order_runs_assignee_idx
  on public.work_order_runs(current_assignee_user_id);
create index work_order_runs_status_idx
  on public.work_order_runs(field_status);
create index work_order_assignments_run_id_idx
  on public.work_order_assignments(run_id);
create index work_order_assignments_organization_id_idx
  on public.work_order_assignments(organization_id);
create index work_order_assignments_user_id_idx
  on public.work_order_assignments(assigned_user_id);
create unique index work_order_assignments_one_open_per_run_idx
  on public.work_order_assignments(run_id)
  where assignment_ended_at is null;

-- Existing rows become Run 1 without inventing assignment history that the
-- pre-Phase-3 projection no longer contains.
insert into public.work_order_runs (
  id,
  work_order_id,
  organization_id,
  run_sequence,
  current_assignee_user_id,
  field_status,
  assignment_received_at,
  started_at,
  field_completed_at,
  requirement_snapshot,
  created_at,
  updated_at,
  closed_at
)
select
  gen_random_uuid(),
  wo.id,
  wo.organization_id,
  1,
  wo.assigned_user_id,
  wo.field_status,
  wo.assignment_received_at,
  wo.started_at,
  wo.field_completed_at,
  '{}'::jsonb,
  wo.created_at,
  wo.updated_at,
  case
    when wo.field_status = 'FIELD_COMPLETE'
      then coalesce(wo.field_completed_at, wo.updated_at)
    when wo.field_status = 'CANCELLED'
      then wo.updated_at
    else null
  end
from public.work_orders wo;

-- Adding the run pointer is a schema backfill, not a business edit. Preserve
-- every existing work-order updated_at timestamp while writing the pointer.
alter table public.work_orders disable trigger work_orders_set_updated_at;

update public.work_orders wo
set current_run_id = r.id,
    current_run_sequence = r.run_sequence
from public.work_order_runs r
where r.work_order_id = wo.id
  and r.run_sequence = 1;

alter table public.work_orders enable trigger work_orders_set_updated_at;

insert into public.work_order_assignments (
  run_id,
  organization_id,
  assigned_user_id,
  assignment_started_at,
  assignment_received_at,
  assignment_ended_at,
  end_reason
)
select
  r.id,
  wo.organization_id,
  wo.assigned_user_id,
  wo.created_at,
  wo.assignment_received_at,
  case
    when wo.field_status = 'FIELD_COMPLETE'
      then coalesce(wo.field_completed_at, wo.updated_at)
    when wo.field_status = 'CANCELLED'
      then wo.updated_at
    else null
  end,
  case
    when wo.field_status = 'FIELD_COMPLETE' then 'FIELD_COMPLETE'
    when wo.field_status = 'CANCELLED' then 'CANCELLED'
    else null
  end
from public.work_orders wo
join public.work_order_runs r
  on r.work_order_id = wo.id
 and r.run_sequence = 1
where wo.assigned_user_id is not null;

alter table public.work_orders
  alter column current_run_id set not null;

alter table public.work_orders
  add constraint work_orders_current_run_same_work_order_fk
  foreign key (current_run_id, id)
  references public.work_order_runs(id, work_order_id)
  deferrable initially deferred;

-- Once run identity exists, every photo record is permanently bound to both
-- the WO and the exact run. The current project has no real photos yet, but
-- this backfill is safe for any valid rows created before Phase 3A lands.
alter table public.photos
  add column run_id uuid;

update public.photos p
set run_id = wo.current_run_id
from public.work_orders wo
where wo.id = p.work_order_id;

alter table public.photos
  alter column run_id set not null;

alter table public.photos
  add constraint photos_run_same_work_order_fk
  foreign key (run_id, work_order_id)
  references public.work_order_runs(id, work_order_id)
  on delete restrict;

create index photos_run_id_idx on public.photos(run_id);

-- New work orders reserve a run identity before constraints are checked.
create or replace function private.prepare_work_order_run_identity()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.current_run_id is null then
    new.current_run_id := gen_random_uuid();
  end if;
  if new.current_run_sequence is null or new.current_run_sequence < 1 then
    new.current_run_sequence := 1;
  end if;
  return new;
end;
$$;

create or replace function private.create_initial_work_order_run()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.work_order_runs (
    id,
    work_order_id,
    organization_id,
    run_sequence,
    current_assignee_user_id,
    field_status,
    assignment_received_at,
    started_at,
    field_completed_at,
    requirement_snapshot,
    created_at,
    updated_at,
    closed_at
  ) values (
    new.current_run_id,
    new.id,
    new.organization_id,
    new.current_run_sequence,
    new.assigned_user_id,
    new.field_status,
    new.assignment_received_at,
    new.started_at,
    new.field_completed_at,
    '{}'::jsonb,
    new.created_at,
    new.updated_at,
    case
      when new.field_status = 'FIELD_COMPLETE'
        then coalesce(new.field_completed_at, new.updated_at)
      when new.field_status = 'CANCELLED'
        then new.updated_at
      else null
    end
  );

  if new.assigned_user_id is not null then
    insert into public.work_order_assignments (
      run_id,
      organization_id,
      assigned_user_id,
      assignment_started_at,
      assignment_received_at,
      assignment_ended_at,
      end_reason
    ) values (
      new.current_run_id,
      new.organization_id,
      new.assigned_user_id,
      new.created_at,
      new.assignment_received_at,
      case
        when new.field_status in ('FIELD_COMPLETE', 'CANCELLED') then new.updated_at
        else null
      end,
      case
        when new.field_status = 'FIELD_COMPLETE' then 'FIELD_COMPLETE'
        when new.field_status = 'CANCELLED' then 'CANCELLED'
        else null
      end
    );
  end if;

  return null;
end;
$$;

create or replace function private.sync_current_work_order_run()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_end_reason text;
begin
  update public.work_order_runs
     set organization_id = new.organization_id,
         current_assignee_user_id = new.assigned_user_id,
         field_status = new.field_status,
         assignment_received_at = new.assignment_received_at,
         started_at = new.started_at,
         field_completed_at = new.field_completed_at,
         updated_at = new.updated_at,
         closed_at = case
           when new.field_status = 'FIELD_COMPLETE'
             then coalesce(new.field_completed_at, new.updated_at)
           when new.field_status = 'CANCELLED'
             then new.updated_at
           else null
         end
   where id = new.current_run_id
     and work_order_id = new.id;

  if new.assigned_user_id is distinct from old.assigned_user_id then
    v_end_reason := case
      when old.field_status = 'IN_PROGRESS' then 'HANDOFF'
      when old.field_status = 'ASSIGNED' then 'REASSIGNED'
      else 'ADMIN_ACTION'
    end;

    update public.work_order_assignments
       set assignment_ended_at = coalesce(assignment_ended_at, new.updated_at),
           end_reason = coalesce(end_reason, v_end_reason)
     where run_id = new.current_run_id
       and assigned_user_id = old.assigned_user_id
       and assignment_ended_at is null;

    if new.assigned_user_id is not null
       and new.field_status not in ('FIELD_COMPLETE', 'CANCELLED') then
      insert into public.work_order_assignments (
        run_id,
        organization_id,
        assigned_user_id,
        assignment_started_at,
        assignment_received_at
      ) values (
        new.current_run_id,
        new.organization_id,
        new.assigned_user_id,
        new.updated_at,
        new.assignment_received_at
      );
    end if;
  end if;

  -- Receipt may be acknowledged after a run is already field-complete. Update
  -- the most recent matching assignment, not only an open assignment.
  if new.assignment_received_at is distinct from old.assignment_received_at
     and new.assigned_user_id is not null then
    update public.work_order_assignments a
       set assignment_received_at = new.assignment_received_at
     where a.id = (
       select a2.id
       from public.work_order_assignments a2
       where a2.run_id = new.current_run_id
         and a2.assigned_user_id = new.assigned_user_id
       order by a2.assignment_started_at desc, a2.created_at desc
       limit 1
     );
  end if;

  if new.field_status in ('FIELD_COMPLETE', 'CANCELLED')
     and new.field_status is distinct from old.field_status then
    update public.work_order_assignments
       set assignment_ended_at = coalesce(assignment_ended_at, new.updated_at),
           end_reason = coalesce(
             end_reason,
             case
               when new.field_status = 'FIELD_COMPLETE' then 'FIELD_COMPLETE'
               else 'CANCELLED'
             end
           )
     where run_id = new.current_run_id
       and assignment_ended_at is null;
  end if;

  return null;
end;
$$;

revoke all on function private.prepare_work_order_run_identity() from public, anon, authenticated;
revoke all on function private.create_initial_work_order_run() from public, anon, authenticated;
revoke all on function private.sync_current_work_order_run() from public, anon, authenticated;

drop trigger if exists work_orders_prepare_run_identity on public.work_orders;
create trigger work_orders_prepare_run_identity
before insert on public.work_orders
for each row execute function private.prepare_work_order_run_identity();

drop trigger if exists work_orders_create_initial_run on public.work_orders;
create trigger work_orders_create_initial_run
after insert on public.work_orders
for each row execute function private.create_initial_work_order_run();

drop trigger if exists work_orders_sync_current_run on public.work_orders;
create trigger work_orders_sync_current_run
after update on public.work_orders
for each row execute function private.sync_current_work_order_run();

alter table public.work_order_runs enable row level security;
alter table public.work_order_assignments enable row level security;

revoke all on public.work_order_runs from public, anon, authenticated;
revoke all on public.work_order_assignments from public, anon, authenticated;

grant select on public.work_order_runs to authenticated;
grant select on public.work_order_assignments to authenticated;
grant all on public.work_order_runs to service_role;
grant all on public.work_order_assignments to service_role;

create policy work_order_runs_select_allowed
on public.work_order_runs
for select
to authenticated
using (
  organization_id = nullif((select auth.jwt() -> 'app_metadata' ->> 'organization_id'), '')::uuid
  and (
    (select auth.jwt() -> 'app_metadata' ->> 'role') = 'ADMIN'
    or current_assignee_user_id = (select auth.uid())
  )
);

create policy work_order_assignments_select_allowed
on public.work_order_assignments
for select
to authenticated
using (
  organization_id = nullif((select auth.jwt() -> 'app_metadata' ->> 'organization_id'), '')::uuid
  and (
    (select auth.jwt() -> 'app_metadata' ->> 'role') = 'ADMIN'
    or assigned_user_id = (select auth.uid())
  )
);

-- Preserve the existing photo policy but require the immutable run binding to
-- match the work order's currently dispatched run for any future insert.
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
      and wo.current_run_id = photos.run_id
      and wo.organization_id = nullif((select auth.jwt() -> 'app_metadata' ->> 'organization_id'), '')::uuid
      and wo.assigned_user_id = (select auth.uid())
      and wo.field_status <> 'CANCELLED'
  )
);
