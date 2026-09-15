alter table public.contractor_invitations
  drop constraint if exists contractor_invitations_status_valid;

alter table public.contractor_invitations
  add constraint contractor_invitations_status_valid
  check (status in ('RESERVED', 'SENT', 'ACCEPTED', 'FAILED', 'PROBLEM', 'CANCELLING', 'CANCELLED'));

alter table public.contractor_invitations
  add column if not exists cancel_requested_by uuid null references auth.users(id) on delete restrict,
  add column if not exists cancel_requested_at timestamptz null,
  add column if not exists cancelled_by uuid null references auth.users(id) on delete restrict,
  add column if not exists cancelled_at timestamptz null,
  add column if not exists cancel_target_auth_user_id uuid null;

alter table public.contractor_invitations
  drop constraint if exists contractor_invitations_auth_user_id_fkey;

alter table public.contractor_invitations
  add constraint contractor_invitations_auth_user_id_fkey
  foreign key (auth_user_id) references auth.users(id) on delete set null;

drop index if exists public.contractor_invitations_live_email_idx;
create unique index contractor_invitations_live_email_idx
  on public.contractor_invitations (organization_id, email)
  where status in ('RESERVED', 'SENT', 'PROBLEM', 'CANCELLING');

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
    and ci.status in ('RESERVED', 'SENT', 'PROBLEM', 'CANCELLING');

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
      and ci.status in ('RESERVED', 'SENT', 'PROBLEM', 'CANCELLING')
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
    and ci.status in ('RESERVED', 'SENT', 'PROBLEM', 'CANCELLING');

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

create or replace function private.admin_list_pending_contractor_invitations()
returns table (
  invitation_id uuid,
  email text,
  display_name text,
  status text,
  created_at timestamptz
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
  select ci.id, ci.email, ci.display_name, ci.status, ci.created_at
  from public.contractor_invitations ci
  where ci.organization_id = v_org
    and ci.status in ('RESERVED', 'SENT', 'PROBLEM', 'CANCELLING')
  order by ci.created_at desc;
end;
$$;

create or replace function private.admin_begin_contractor_invitation_cancel(
  p_invitation_id uuid
)
returns table (
  invitation_id uuid,
  email text,
  display_name text,
  status text,
  auth_user_id uuid,
  organization_id uuid
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_org uuid := nullif(auth.jwt() -> 'app_metadata' ->> 'organization_id', '')::uuid;
  v_role text := auth.jwt() -> 'app_metadata' ->> 'role';
  v_row public.contractor_invitations%rowtype;
  v_user auth.users%rowtype;
begin
  if v_uid is null then
    raise exception 'Authentication required' using errcode = '42501';
  end if;

  if v_role <> 'ADMIN' or v_org is null then
    raise exception 'Admin permission required' using errcode = '42501';
  end if;

  select * into v_row
  from public.contractor_invitations ci
  where ci.id = p_invitation_id
  for update;

  if not found or v_row.organization_id is distinct from v_org then
    raise exception 'Invitation not available to this Admin' using errcode = '42501';
  end if;

  if v_row.status not in ('RESERVED', 'SENT', 'PROBLEM') then
    raise exception 'Only a pending unaccepted invitation can be cancelled' using errcode = '22023';
  end if;

  if v_row.auth_user_id is not null then
    select * into v_user
    from auth.users u
    where u.id = v_row.auth_user_id
      and u.deleted_at is null;

    if not found then
      raise exception 'Invitation Auth identity is missing and requires reconciliation' using errcode = '42501';
    end if;

    if lower(coalesce(v_user.email, '')) <> v_row.email
       or v_user.email_confirmed_at is not null
       or v_user.last_sign_in_at is not null
       or v_user.raw_app_meta_data ->> 'role' <> 'CONTRACTOR'
       or v_user.raw_app_meta_data ->> 'organization_id' <> v_org::text
       or v_user.raw_user_meta_data ->> 'team_invitation_id' <> v_row.id::text then
      raise exception 'This invitation can no longer be safely cancelled as an unused account' using errcode = '42501';
    end if;

    if exists (
      select 1
      from public.work_orders w
      where w.assigned_user_id = v_row.auth_user_id
         or w.pending_assignee_user_id = v_row.auth_user_id
    ) then
      raise exception 'This Contractor identity is referenced by a work order and cannot be deleted' using errcode = '42501';
    end if;
  end if;

  update public.contractor_invitations
     set status = 'CANCELLING',
         cancel_requested_by = v_uid,
         cancel_requested_at = now(),
         cancel_target_auth_user_id = auth_user_id,
         updated_at = now()
   where id = v_row.id
   returning * into v_row;

  return query
  select v_row.id, v_row.email, v_row.display_name, v_row.status, v_row.auth_user_id, v_row.organization_id;
end;
$$;

create or replace function public.admin_list_pending_contractor_invitations()
returns table (
  invitation_id uuid,
  email text,
  display_name text,
  status text,
  created_at timestamptz
)
language sql
security invoker
set search_path = ''
as $$
  select * from private.admin_list_pending_contractor_invitations();
$$;

create or replace function public.admin_begin_contractor_invitation_cancel(
  p_invitation_id uuid
)
returns table (
  invitation_id uuid,
  email text,
  display_name text,
  status text,
  auth_user_id uuid,
  organization_id uuid
)
language sql
security invoker
set search_path = ''
as $$
  select * from private.admin_begin_contractor_invitation_cancel(p_invitation_id);
$$;

create or replace function public.team_finalize_contractor_invitation_cancel(
  p_invitation_id uuid,
  p_outcome text
)
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
  v_outcome text := upper(btrim(coalesce(p_outcome, '')));
  v_row public.contractor_invitations%rowtype;
begin
  if v_outcome not in ('CANCELLED', 'PROBLEM') then
    raise exception 'Invalid cancellation outcome' using errcode = '22023';
  end if;

  select * into v_row
  from public.contractor_invitations ci
  where ci.id = p_invitation_id
  for update;

  if not found then
    raise exception 'Invitation not found' using errcode = '22023';
  end if;

  if v_row.status <> 'CANCELLING' then
    raise exception 'Invitation is not awaiting cancellation finalization' using errcode = '22023';
  end if;

  if v_outcome = 'CANCELLED' then
    if v_row.cancel_target_auth_user_id is not null then
      if v_row.auth_user_id is not null
         or exists (select 1 from auth.users u where u.id = v_row.cancel_target_auth_user_id) then
        raise exception 'Auth identity still exists; cancellation cannot be finalized' using errcode = '42501';
      end if;
    end if;

    update public.contractor_invitations
       set status = 'CANCELLED',
           cancelled_by = cancel_requested_by,
           cancelled_at = now(),
           updated_at = now()
     where id = v_row.id
     returning * into v_row;
  else
    update public.contractor_invitations
       set status = 'PROBLEM',
           updated_at = now()
     where id = v_row.id
     returning * into v_row;
  end if;

  return query
  select v_row.id, v_row.email, v_row.display_name, v_row.status;
end;
$$;

revoke all on function private.admin_list_pending_contractor_invitations() from public, anon;
revoke all on function private.admin_begin_contractor_invitation_cancel(uuid) from public, anon;
grant execute on function private.admin_list_pending_contractor_invitations() to authenticated, service_role;
grant execute on function private.admin_begin_contractor_invitation_cancel(uuid) to authenticated, service_role;

revoke all on function public.admin_list_pending_contractor_invitations() from public, anon;
revoke all on function public.admin_begin_contractor_invitation_cancel(uuid) from public, anon;
grant execute on function public.admin_list_pending_contractor_invitations() to authenticated, service_role;
grant execute on function public.admin_begin_contractor_invitation_cancel(uuid) to authenticated, service_role;

revoke all on function public.team_finalize_contractor_invitation_cancel(uuid, text) from public, anon, authenticated;
grant execute on function public.team_finalize_contractor_invitation_cancel(uuid, text) to service_role;