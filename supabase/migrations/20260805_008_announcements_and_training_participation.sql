-- Vereinsmeldungen ---------------------------------------------------------
create table public.club_announcements (
  id bigint generated always as identity primary key,
  title text not null check (char_length(title) between 1 and 80),
  message text not null check (char_length(message) between 1 and 500),
  expires_at timestamptz,
  created_by uuid references public.profiles(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.club_announcements enable row level security;
create policy "Everyone can read active announcements"
on public.club_announcements for select to anon, authenticated
using (expires_at is null or expires_at > now());
create policy "Trainers can create announcements"
on public.club_announcements for insert to authenticated
with check (public.can_review_memberships() and created_by = auth.uid());
create policy "Trainers can update announcements"
on public.club_announcements for update to authenticated
using (public.can_review_memberships()) with check (public.can_review_memberships());
create policy "Trainers can delete announcements"
on public.club_announcements for delete to authenticated
using (public.can_review_memberships());
grant select on public.club_announcements to anon, authenticated;
grant insert, update, delete on public.club_announcements to authenticated;
grant usage, select on sequence public.club_announcements_id_seq to authenticated;
create trigger club_announcements_set_updated_at before update
on public.club_announcements for each row execute procedure public.set_updated_at();

-- Trainingsberechtigung getrennt von der Kontorolle -----------------------
alter table public.profiles
  add column can_respond_training boolean not null default false,
  add column training_group text
    check (training_group in ('Männer', 'Jugend', 'Bambinis'));

create or replace function public.set_training_access(
  target_user_id uuid,
  enabled boolean,
  assigned_group text default null
)
returns void language plpgsql security definer set search_path = '' as $$
begin
  if not public.is_admin() then raise exception 'admin_required'; end if;
  if enabled and assigned_group not in ('Männer', 'Jugend', 'Bambinis') then
    raise exception 'training_group_required';
  end if;
  update public.profiles set
    can_respond_training = enabled,
    training_group = case when enabled then assigned_group else null end
  where id = target_user_id and membership_status = 'approved';
  if not found then raise exception 'approved_profile_not_found'; end if;
end;
$$;
revoke all on function public.set_training_access(uuid, boolean, text) from public;
grant execute on function public.set_training_access(uuid, boolean, text) to authenticated;

-- Dauerhafte Antworten auf dynamisch erzeugte Trainingstermine ------------
create table public.weekly_training_responses (
  schedule_id bigint not null references public.weekly_training_schedule(id) on delete cascade,
  training_date date not null,
  user_id uuid not null references public.profiles(id) on delete cascade,
  status text not null check (status in ('accepted', 'declined')),
  decline_reason text,
  updated_at timestamptz not null default now(),
  primary key (schedule_id, training_date, user_id),
  check (status = 'accepted' or nullif(btrim(decline_reason), '') is not null)
);

alter table public.weekly_training_responses enable row level security;
create policy "Approved members can read training responses"
on public.weekly_training_responses for select to authenticated
using (public.is_approved_member());
grant select on public.weekly_training_responses to authenticated;

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
    select 1 from public.profiles where id = auth.uid()
      and membership_status = 'approved' and can_respond_training
      and training_group = schedule_group
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
revoke all on function public.respond_to_training(bigint, date, text, text) from public;
grant execute on function public.respond_to_training(bigint, date, text, text) to authenticated;

create trigger weekly_training_responses_set_updated_at before update
on public.weekly_training_responses for each row execute procedure public.set_updated_at();
