-- Ein gemeinsamer Wochenplan fuer Gaeste- und Mitgliederansicht.
create table public.weekly_training_schedule (
  id bigint generated always as identity primary key,
  group_name text not null check (group_name in ('Männer', 'Jugend', 'Bambinis')),
  weekday smallint not null check (weekday between 1 and 7),
  start_hour smallint not null check (start_hour between 0 and 23),
  start_minute smallint not null check (start_minute between 0 and 59),
  end_hour smallint not null check (end_hour between 0 and 23),
  end_minute smallint not null check (end_minute between 0 and 59),
  location_name text not null default 'KSC Trainingshalle',
  location_query text not null default 'KSC Olympia Graben-Neudorf',
  updated_at timestamptz not null default now(),
  unique (group_name, weekday),
  check ((end_hour * 60 + end_minute) > (start_hour * 60 + start_minute))
);

insert into public.weekly_training_schedule
  (group_name, weekday, start_hour, start_minute, end_hour, end_minute)
values
  ('Bambinis', 1, 16, 0, 17, 0),
  ('Jugend', 1, 17, 0, 19, 0),
  ('Männer', 2, 18, 0, 20, 0),
  ('Bambinis', 3, 16, 0, 17, 0),
  ('Jugend', 3, 17, 0, 19, 0),
  ('Männer', 4, 18, 0, 20, 0);

alter table public.weekly_training_schedule enable row level security;

create policy "Everyone can read the weekly training schedule"
on public.weekly_training_schedule for select
to anon, authenticated
using (true);

create policy "Admins can update the weekly training schedule"
on public.weekly_training_schedule for update
to authenticated
using (public.is_admin())
with check (public.is_admin());

grant select on public.weekly_training_schedule to anon, authenticated;
grant update on public.weekly_training_schedule to authenticated;

create trigger weekly_training_schedule_set_updated_at
  before update on public.weekly_training_schedule
  for each row execute procedure public.set_updated_at();
