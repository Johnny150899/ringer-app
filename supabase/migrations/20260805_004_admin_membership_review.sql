-- Nur bestätigte Administratoren dürfen Mitgliedsanträge bearbeiten.
create or replace function public.review_membership_request(
  target_user_id uuid,
  approve boolean
)
returns void
language plpgsql
security definer set search_path = ''
as $$
begin
  if not public.is_admin() then
    raise exception 'admin_required';
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
