-- Einmalige Willkommensmeldung nach der Genehmigung eines Mitgliedsantrags.

alter table public.profiles
  add column if not exists membership_approved_at timestamptz,
  add column if not exists membership_welcome_seen_at timestamptz;

create or replace function public.review_membership_request(
  target_user_id uuid,
  approve boolean
)
returns void
language plpgsql
security definer set search_path = ''
as $$
begin
  if not public.can_review_memberships() then
    raise exception 'trainer_or_admin_required';
  end if;

  update public.profiles
  set
    role = case when approve then 'member' else 'fan' end,
    membership_status = case when approve then 'approved' else 'rejected' end,
    membership_approved_at = case when approve then now() else null end,
    membership_welcome_seen_at = null
  where id = target_user_id
    and role = 'member'
    and membership_status = 'pending';

  if not found then
    raise exception 'membership_request_not_found';
  end if;
end;
$$;

grant execute on function public.review_membership_request(uuid, boolean)
to authenticated;

create or replace function public.acknowledge_membership_welcome()
returns void
language sql
security definer set search_path = ''
as $$
  update public.profiles
  set membership_welcome_seen_at = now()
  where id = auth.uid()
    and membership_status = 'approved'
    and membership_approved_at is not null
    and membership_welcome_seen_at is null;
$$;

grant execute on function public.acknowledge_membership_welcome()
to authenticated;

-- Profiländerungen sollen beim betroffenen Benutzer sofort ankommen.
do $$
begin
  if not exists (
    select 1
    from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'profiles'
  ) then
    alter publication supabase_realtime add table public.profiles;
  end if;
end;
$$;
