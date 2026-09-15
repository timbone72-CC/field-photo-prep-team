create index if not exists contractor_invitations_cancel_requested_by_idx
  on public.contractor_invitations (cancel_requested_by)
  where cancel_requested_by is not null;

create index if not exists contractor_invitations_cancelled_by_idx
  on public.contractor_invitations (cancelled_by)
  where cancelled_by is not null;