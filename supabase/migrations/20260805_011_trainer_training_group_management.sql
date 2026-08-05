-- Trainer duerfen Trainingsgruppen verwalten, aber keine Kontorollen.
create or replace function public.set_training_groups(
  target_user_id uuid,
  assigned_groups text[]
)
returns void language plpgsql security definer set search_path = '' as $$
begin
  if not public.can_review_memberships() then
    raise exception 'trainer_or_admin_required';
  end if;
  if exists (
    select 1 from unnest(assigned_groups) value
    where value not in ('Männer', 'Jugend', 'Bambinis')
  ) then raise exception 'invalid_training_group'; end if;
  if not exists (
    select 1 from public.profiles where id = target_user_id
      and membership_status = 'approved'
  ) then raise exception 'approved_profile_not_found'; end if;

  delete from public.profile_training_groups where user_id = target_user_id;
  insert into public.profile_training_groups (user_id, group_name)
  select target_user_id, value from unnest(assigned_groups) value;

  update public.profiles set
    can_respond_training = cardinality(assigned_groups) > 0,
    training_group = assigned_groups[1]
  where id = target_user_id;
end;
$$;

revoke all on function public.set_training_groups(uuid, text[]) from public;
grant execute on function public.set_training_groups(uuid, text[]) to authenticated;
