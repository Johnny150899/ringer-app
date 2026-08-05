-- Trainer erhalten Zugriff auf die Bearbeitung von Mitgliedsanträgen.
alter table public.profiles
  drop constraint profiles_role_check;

alter table public.profiles
  add constraint profiles_role_check
    check (role in ('fan', 'member', 'trainer', 'admin'));

create or replace function public.can_review_memberships()
returns boolean
language sql
stable
security definer set search_path = ''
as $$
  select exists (
    select 1
    from public.profiles
    where id = auth.uid()
      and membership_status = 'approved'
      and role in ('trainer', 'admin')
  );
$$;

grant execute on function public.can_review_memberships() to authenticated;

create policy "Trainers can read pending membership requests"
on public.profiles for select
to authenticated
using (
  role = 'member'
  and membership_status = 'pending'
  and public.can_review_memberships()
);

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
    membership_status = case when approve then 'approved' else 'rejected' end
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
