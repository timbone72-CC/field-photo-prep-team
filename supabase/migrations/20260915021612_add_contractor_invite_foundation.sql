alter table public.organizations
  add column if not exists contractor_seat_limit integer not null default 2;

alter table public.organizations
  drop constraint if exists organizations_contractor_seat_limit_positive;

alter table public.organizations
  add constraint organizations_contractor_seat_limit_positive
  check (contractor_seat_limit > 0);

create table if not exists public.contractor_invitations (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete restrict,
  email text not null,
  display_name text not null,
  status text not null default 'RESERVED',
  auth_user_id uuid null references auth.users(id) on delete restrict,
  created_by uuid not null references auth.users(id) on delete restrict,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint contractor_invitations_email_normalized
    check (email = lower(btrim(email)) and char_length(email) between 3 and 320),
  constraint contractor_invitations_display_name_nonempty
    check (char_length(btrim(display_name)) between 1 and 200),
  constraint contractor_invitations_status_valid
    check (status in ('RESERVED', 'SENT', 'ACCEPTED', 'FAILED', 'PROBLEM'))
);

create unique index if not exists contractor_invitations_live_email_idx
  on public.contractor_invitations (organization_id, email)
  where status in ('RESERVED', 'SENT', 'PROBLEM');

create index if not exists contractor_invitations_org_status_idx
  on public.contractor_invitations (organization_id, status);

create index if not exists contractor_invitations_auth_user_idx
  on public.contractor_invitations (auth_user_id)
  where auth_user_id is not null;

alter table public.contractor_invitations enable row level security;
revoke all on table public.contractor_invitations from public, anon, authenticated;
grant select, insert, update on table public.contractor_invitations to service_role;

create or replace function private.is_assignable_contractor(
  p_user_id uuid,
  p_organization_id uuid
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from auth.users u
    where u.id = p_user_id
      and u.deleted_at is null
      and u.email_confirmed_at is not null
      and (u.banned_until is null or u.banned_until <= now())
      and u.raw_app_meta_data ->> 'organization_id' = p_organization_id::text
      and u.raw_app_meta_data ->> 'role' = 'CONTRACTOR'
      and not exists (
        select 1
        from public.contractor_invitations ci
        where ci.auth_user_id = u.id
          and ci.status <> 'ACCEPTED'
      )
  );
$$;

revoke all on function private.is_assignable_contractor(uuid, uuid) from public, anon, authenticated;
grant execute on function private.is_assignable_contractor(uuid, uuid) to service_role;

create or replace function private.enforce_work_order_assignable_contractors()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.assigned_user_id is not null
     and not private.is_assignable_contractor(new.assigned_user_id, new.organization_id) then
    raise exception 'Assignee is not an active accepted Contractor in this organization'
      using errcode = '42501';
  end if;

  if new.pending_assignee_user_id is not null
     and not private.is_assignable_contractor(new.pending_assignee_user_id, new.organization_id) then
    raise exception 'Pending assignee is not an active accepted Contractor in this organization'
      using errcode = '42501';
  end if;

  return new;
end;
$$;

revoke all on function private.enforce_work_order_assignable_contractors() from public, anon, authenticated;
grant execute on function private.enforce_work_order_assignable_contractors() to service_role;

drop trigger if exists work_orders_enforce_assignable_contractors on public.work_orders;
create trigger work_orders_enforce_assignable_contractors
before insert or update of assigned_user_id, pending_assignee_user_id
on public.work_orders
for each row execute function private.enforce_work_order_assignable_contractors();

create or replace function private.admin_list_assignable_users()
returns table (
  user_id uuid,
  email text,
  role text
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_org uuid := nullif(auth.jwt() -> 'app_metadata' ->> 'organization_id', '')::uuid;
  v_role text := auth.jwt() -> 'app_metadata' ->> 'role';
begin
  if v_uid is null then
    raise exception 'Authentication required' using errcode = '42501';
  end if;

  if v_role <> 'ADMIN' or v_org is null then
    raise exception 'Admin permission required' using errcode = '42501';
  end if;

  return query
  select
    u.id,
    u.email::text,
    u.raw_app_meta_data ->> 'role'
  from auth.users u
  where private.is_assignable_contractor(u.id, v_org)
  order by lower(u.email);
end;
$$;

create or replace function private.admin_get_contractor_seat_summary()
returns table (
  seat_limit integer,
  active_contractors integer,
  pending_invitations integer,
  used_seats integer,
  available_seats integer
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_org uuid := nullif(auth.jwt() -> 'app_metadata' ->> 'organization_id', '')::uuid;
  v_role text := auth.jwt() -> 'app_metadata' ->> 'role';
  v_limit integer;
  v_active integer;
  v_pending integer;
begin
  if v_uid is null then
    raise exception 'Authentication required' using errcode = '42501';
  end if;

  if v_role <> 'ADMIN' or v_org is null then
    raise exception 'Admin permission required' using errcode = '42501';
  end if;

  select o.contractor_seat_limit
    into v_limit
  from public.organizations o
  where o.id = v_org;

  if v_limit is null then
    raise exception 'Organization not available' using errcode = '42501';
  end if;

  select count(*)::integer
    into v_active
  from auth.users u
  where private.is_assignable_contractor(u.id, v_org);

  select count(*)::integer
    into v_pending
  from public.contractor_invitations ci
  where ci.organization_id = v_org
    and ci.status in ('RESERVED', 'SENT', 'PROBLEM');

  return query
  select
    v_limit,
    v_active,
    v_pending,
    v_active + v_pending,
    greatest(v_limit - v_active - v_pending, 0);
end;
$$;

create or replace function private.admin_reserve_contractor_invitation(
  p_email text,
  p_display_name text
)
returns table (
  invitation_id uuid,
  email text,
  display_name text,
  status text,
  organization_id uuid,
  seat_limit integer,
  used_seats integer,
  available_seats integer
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_org uuid := nullif(auth.jwt() -> 'app_metadata' ->> 'organization_id', '')::uuid;
  v_role text := auth.jwt() -> 'app_metadata' ->> 'role';
  v_email text := lower(btrim(coalesce(p_email, '')));
  v_name text := btrim(coalesce(p_display_name, ''));
  v_limit integer;
  v_active integer;
  v_pending integer;
  v_row public.contractor_invitations%rowtype;
begin
  if v_uid is null then
    raise exception 'Authentication required' using errcode = '42501';
  end if;

  if v_role <> 'ADMIN' or v_org is null then
    raise exception 'Admin permission required' using errcode = '42501';
  end if;

  if char_length(v_name) < 1 or char_length(v_name) > 200 then
    raise exception 'Contractor name is required and must be 200 characters or fewer' using errcode = '22023';
  end if;

  if char_length(v_email) < 3
     or char_length(v_email) > 320
     or v_email !~ '^[^[:space:]@]+@[^[:space:]@]+\.[^[:space:]@]+$' then
    raise exception 'A valid contractor email is required' using errcode = '22023';
  end if;

  select o.contractor_seat_limit
    into v_limit
  from public.organizations o
  where o.id = v_org
  for update;

  if v_limit is null then
    raise exception 'Organization not available' using errcode = '42501';
  end if;

  if exists (
    select 1
    from auth.users u
    where u.deleted_at is null
      and lower(u.email) = v_email
  ) then
    raise exception 'That email already belongs to a Team Auth user' using errcode = '23505';
  end if;

  if exists (
    select 1
    from public.contractor_invitations ci
    where ci.organization_id = v_org
      and ci.email = v_email
      and ci.status in ('RESERVED', 'SENT', 'PROBLEM')
  ) then
    raise exception 'A live invitation already exists for that email' using errcode = '23505';
  end if;

  select count(*)::integer
    into v_active
  from auth.users u
  where private.is_assignable_contractor(u.id, v_org);

  select count(*)::integer
    into v_pending
  from public.contractor_invitations ci
  where ci.organization_id = v_org
    and ci.status in ('RESERVED', 'SENT', 'PROBLEM');

  if v_active + v_pending >= v_limit then
    raise exception 'No Contractor seat is available' using errcode = '22023';
  end if;

  insert into public.contractor_invitations (
    organization_id,
    email,
    display_name,
    status,
    created_by
  ) values (
    v_org,
    v_email,
    v_name,
    'RESERVED',
    v_uid
  )
  returning * into v_row;

  return query
  select
    v_row.id,
    v_row.email,
    v_row.display_name,
    v_row.status,
    v_row.organization_id,
    v_limit,
    v_active + v_pending + 1,
    greatest(v_limit - v_active - v_pending - 1, 0);
exception
  when unique_violation then
    raise exception 'A live invitation already exists for that email' using errcode = '23505';
end;
$$;

create or replace function private.complete_contractor_invitation_activation()
returns table (
  invitation_id uuid,
  email text,
  display_name text,
  status text
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_org uuid := nullif(auth.jwt() -> 'app_metadata' ->> 'organization_id', '')::uuid;
  v_role text := auth.jwt() -> 'app_metadata' ->> 'role';
  v_auth_email text;
  v_confirmed timestamptz;
  v_row public.contractor_invitations%rowtype;
begin
  if v_uid is null then
    raise exception 'Authentication required' using errcode = '42501';
  end if;

  if v_role <> 'CONTRACTOR' or v_org is null then
    raise exception 'Contractor permission required' using errcode = '42501';
  end if;

  select lower(u.email), u.email_confirmed_at
    into v_auth_email, v_confirmed
  from auth.users u
  where u.id = v_uid
    and u.deleted_at is null;

  if v_auth_email is null or v_confirmed is null then
    raise exception 'Invited email is not confirmed' using errcode = '42501';
  end if;

  select *
    into v_row
  from public.contractor_invitations ci
  where ci.organization_id = v_org
    and ci.auth_user_id = v_uid
    and ci.email = v_auth_email
    and ci.status = 'SENT'
  order by ci.created_at desc
  limit 1
  for update;

  if not found then
    raise exception 'No pending Contractor invitation is available for this account' using errcode = '42501';
  end if;

  update public.contractor_invitations
     set status = 'ACCEPTED',
         updated_at = now()
   where id = v_row.id
   returning * into v_row;

  return query
  select v_row.id, v_row.email, v_row.display_name, v_row.status;
end;
$$;

create or replace function public.admin_get_contractor_seat_summary()
returns table (
  seat_limit integer,
  active_contractors integer,
  pending_invitations integer,
  used_seats integer,
  available_seats integer
)
language sql
security invoker
set search_path = ''
as $$
  select * from private.admin_get_contractor_seat_summary();
$$;

create or replace function public.admin_reserve_contractor_invitation(
  p_email text,
  p_display_name text
)
returns table (
  invitation_id uuid,
  email text,
  display_name text,
  status text,
  organization_id uuid,
  seat_limit integer,
  used_seats integer,
  available_seats integer
)
language sql
security invoker
set search_path = ''
as $$
  select * from private.admin_reserve_contractor_invitation(p_email, p_display_name);
$$;

create or replace function public.complete_contractor_invitation_activation()
returns table (
  invitation_id uuid,
  email text,
  display_name text,
  status text
)
language sql
security invoker
set search_path = ''
as $$
  select * from private.complete_contractor_invitation_activation();
$$;

create or replace function public.team_finalize_contractor_invitation(
  p_invitation_id uuid,
  p_outcome text,
  p_auth_user_id uuid default null
)
returns table (
  invitation_id uuid,
  email text,
  display_name text,
  status text,
  auth_user_id uuid
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_outcome text := upper(btrim(coalesce(p_outcome, '')));
  v_row public.contractor_invitations%rowtype;
  v_user auth.users%rowtype;
begin
  if v_outcome not in ('SENT', 'FAILED', 'PROBLEM') then
    raise exception 'Invalid invitation outcome' using errcode = '22023';
  end if;

  select *
    into v_row
  from public.contractor_invitations ci
  where ci.id = p_invitation_id
  for update;

  if not found then
    raise exception 'Invitation not found' using errcode = '22023';
  end if;

  if v_row.status <> 'RESERVED' then
    raise exception 'Invitation is not reserved' using errcode = '22023';
  end if;

  if v_outcome = 'SENT' then
    if p_auth_user_id is null then
      raise exception 'Auth user is required for sent invitation' using errcode = '22023';
    end if;

    select *
      into v_user
    from auth.users u
    where u.id = p_auth_user_id
      and u.deleted_at is null;

    if not found
       or lower(v_user.email) <> v_row.email
       or v_user.raw_app_meta_data ->> 'role' <> 'CONTRACTOR'
       or v_user.raw_app_meta_data ->> 'organization_id' <> v_row.organization_id::text then
      raise exception 'Auth user does not match the reserved Contractor invitation' using errcode = '42501';
    end if;

    update public.contractor_invitations
       set status = 'SENT',
           auth_user_id = p_auth_user_id,
           updated_at = now()
     where id = p_invitation_id
     returning * into v_row;
  elsif v_outcome = 'FAILED' then
    if p_auth_user_id is not null then
      raise exception 'Known failure cannot retain an Auth user' using errcode = '22023';
    end if;

    update public.contractor_invitations
       set status = 'FAILED',
           auth_user_id = null,
           updated_at = now()
     where id = p_invitation_id
     returning * into v_row;
  else
    update public.contractor_invitations
       set status = 'PROBLEM',
           auth_user_id = p_auth_user_id,
           updated_at = now()
     where id = p_invitation_id
     returning * into v_row;
  end if;

  return query
  select v_row.id, v_row.email, v_row.display_name, v_row.status, v_row.auth_user_id;
end;
$$;

revoke all on function private.admin_list_assignable_users() from public, anon;
grant execute on function private.admin_list_assignable_users() to authenticated, service_role;

revoke all on function private.admin_get_contractor_seat_summary() from public, anon;
revoke all on function private.admin_reserve_contractor_invitation(text, text) from public, anon;
revoke all on function private.complete_contractor_invitation_activation() from public, anon;
grant execute on function private.admin_get_contractor_seat_summary() to authenticated, service_role;
grant execute on function private.admin_reserve_contractor_invitation(text, text) to authenticated, service_role;
grant execute on function private.complete_contractor_invitation_activation() to authenticated, service_role;

revoke all on function public.admin_get_contractor_seat_summary() from public, anon;
revoke all on function public.admin_reserve_contractor_invitation(text, text) from public, anon;
revoke all on function public.complete_contractor_invitation_activation() from public, anon;
grant execute on function public.admin_get_contractor_seat_summary() to authenticated, service_role;
grant execute on function public.admin_reserve_contractor_invitation(text, text) to authenticated, service_role;
grant execute on function public.complete_contractor_invitation_activation() to authenticated, service_role;

revoke all on function public.team_finalize_contractor_invitation(uuid, text, uuid) from public, anon, authenticated;
grant execute on function public.team_finalize_contractor_invitation(uuid, text, uuid) to service_role;
