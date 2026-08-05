-- Ausschliesslich bestaetigte Administratoren duerfen Rollen verwalten.
create or replace function public.set_user_role(
  target_user_id uuid,
  new_role text
)
returns void
language plpgsql
security definer set search_path = ''
as $$
begin
  if not public.is_admin() then
    raise exception 'admin_required';
  end if;

  if target_user_id = auth.uid() then
    raise exception 'cannot_change_own_role';
  end if;

  if new_role not in ('fan', 'member', 'trainer', 'admin') then
    raise exception 'invalid_role';
  end if;

  update public.profiles
  set
    role = new_role,
    membership_status = case
      when new_role = 'fan' then 'not_requested'
      else 'approved'
    end
  where id = target_user_id;

  if not found then
    raise exception 'profile_not_found';
  end if;
end;
$$;

revoke all on function public.set_user_role(uuid, text) from public;
grant execute on function public.set_user_role(uuid, text) to authenticated;
