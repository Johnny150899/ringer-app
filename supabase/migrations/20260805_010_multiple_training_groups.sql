-- Mehrere Trainingsgruppen pro aktivem Ringer.
create table public.profile_training_groups (
  user_id uuid not null references public.profiles(id) on delete cascade,
  group_name text not null check (group_name in ('Männer', 'Jugend', 'Bambinis')),
  created_at timestamptz not null default now(),
  primary key (user_id, group_name)
);

insert into public.profile_training_groups (user_id, group_name)
select id, training_group from public.profiles
where can_respond_training and training_group is not null
on conflict do nothing;

alter table public.profile_training_groups enable row level security;
create policy "Members can read training groups"
on public.profile_training_groups for select to authenticated
using (public.is_approved_member());
grant select on public.profile_training_groups to authenticated;

create or replace function public.set_training_groups(
  target_user_id uuid,
  assigned_groups text[]
)
returns void language plpgsql security definer set search_path = '' as $$
begin
  if not public.is_admin() then raise exception 'admin_required'; end if;
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

  -- Die alten Felder bleiben vorerst synchron, damit ältere App-Versionen laufen.
  update public.profiles set
    can_respond_training = cardinality(assigned_groups) > 0,
    training_group = assigned_groups[1]
  where id = target_user_id;
end;
$$;
revoke all on function public.set_training_groups(uuid, text[]) from public;
grant execute on function public.set_training_groups(uuid, text[]) to authenticated;

create or replace function public.respond_to_training(
  target_schedule_id bigint,
  target_date date,
  new_status text,
  reason text default null
)
returns void language plpgsql security definer set search_path = '' as $$
declare schedule_group text;
begin
  select group_name into schedule_group from public.weekly_training_schedule
  where id = target_schedule_id;
  if not exists (
    select 1 from public.profiles p
    join public.profile_training_groups g on g.user_id = p.id
    where p.id = auth.uid() and p.membership_status = 'approved'
      and g.group_name = schedule_group
  ) then raise exception 'training_response_not_allowed'; end if;
  if new_status not in ('accepted', 'declined') then raise exception 'invalid_status'; end if;
  if new_status = 'declined' and nullif(btrim(reason), '') is null then
    raise exception 'decline_reason_required';
  end if;
  insert into public.weekly_training_responses
    (schedule_id, training_date, user_id, status, decline_reason)
  values
    (target_schedule_id, target_date, auth.uid(), new_status,
     case when new_status = 'declined' then btrim(reason) else null end)
  on conflict (schedule_id, training_date, user_id) do update set
    status = excluded.status, decline_reason = excluded.decline_reason,
    updated_at = now();
end;
$$;
