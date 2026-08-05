-- Benutzerprofile -----------------------------------------------------------
create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  full_name text not null default '',
  role text not null default 'member'
    check (role in ('member', 'admin')),
  membership_status text not null default 'pending'
    check (membership_status in ('pending', 'approved', 'rejected')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.profiles enable row level security;

-- Erstellt nach einer Registrierung automatisch das zugehörige Profil.
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer set search_path = ''
as $$
begin
  insert into public.profiles (id, full_name)
  values (new.id, coalesce(new.raw_user_meta_data ->> 'full_name', ''));
  return new;
end;
$$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute procedure public.handle_new_user();

-- Sicherheitsfunktionen ohne rekursive RLS-Abfragen.
create or replace function public.is_approved_member()
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
  );
$$;

create or replace function public.is_admin()
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
      and role = 'admin'
  );
$$;

grant execute on function public.is_approved_member() to authenticated;
grant execute on function public.is_admin() to authenticated;

create policy "Users can read their own profile"
on public.profiles for select
to authenticated
using (id = auth.uid());

create policy "Approved members can read approved profiles"
on public.profiles for select
to authenticated
using (
  membership_status = 'approved'
  and public.is_approved_member()
);

create policy "Admins can read every profile"
on public.profiles for select
to authenticated
using (public.is_admin());

create policy "Users can update their own profile"
on public.profiles for update
to authenticated
using (id = auth.uid())
with check (id = auth.uid());

grant select on public.profiles to authenticated;
-- Mitglieder dürfen nur ihren Namen, niemals Rolle oder Freigabe ändern.
grant update (full_name) on public.profiles to authenticated;

-- Konkrete Trainingstermine -------------------------------------------------
create table public.training_events (
  id bigint generated always as identity primary key,
  group_name text not null
    check (group_name in ('Männer', 'Jugend', 'Bambinis')),
  starts_at timestamptz not null,
  ends_at timestamptz not null,
  notes text,
  is_cancelled boolean not null default false,
  created_by uuid references public.profiles(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (ends_at > starts_at)
);

alter table public.training_events enable row level security;

create policy "Approved members can read training events"
on public.training_events for select
to authenticated
using (public.is_approved_member());

create policy "Admins can create training events"
on public.training_events for insert
to authenticated
with check (public.is_admin());

create policy "Admins can update training events"
on public.training_events for update
to authenticated
using (public.is_admin())
with check (public.is_admin());

create policy "Admins can delete training events"
on public.training_events for delete
to authenticated
using (public.is_admin());

grant select, insert, update, delete on public.training_events to authenticated;
grant usage, select on sequence public.training_events_id_seq to authenticated;

-- Zu- und Absagen -----------------------------------------------------------
create table public.training_responses (
  training_event_id bigint not null
    references public.training_events(id) on delete cascade,
  user_id uuid not null
    references public.profiles(id) on delete cascade,
  response text not null check (response in ('accepted', 'declined')),
  decline_reason text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key (training_event_id, user_id),
  check (
    (response = 'accepted' and decline_reason is null)
    or
    (response = 'declined' and length(trim(decline_reason)) > 0)
  )
);

alter table public.training_responses enable row level security;

create policy "Approved members can read training responses"
on public.training_responses for select
to authenticated
using (public.is_approved_member());

create policy "Members can create their own response"
on public.training_responses for insert
to authenticated
with check (
  user_id = auth.uid()
  and public.is_approved_member()
);

create policy "Members can update their own response"
on public.training_responses for update
to authenticated
using (
  user_id = auth.uid()
  and public.is_approved_member()
)
with check (
  user_id = auth.uid()
  and public.is_approved_member()
);

create policy "Members can delete their own response"
on public.training_responses for delete
to authenticated
using (
  user_id = auth.uid()
  and public.is_approved_member()
);

grant select, insert, update, delete on public.training_responses
to authenticated;

-- Hält updated_at automatisch aktuell.
create or replace function public.set_updated_at()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create trigger profiles_set_updated_at
  before update on public.profiles
  for each row execute procedure public.set_updated_at();

create trigger training_events_set_updated_at
  before update on public.training_events
  for each row execute procedure public.set_updated_at();

create trigger training_responses_set_updated_at
  before update on public.training_responses
  for each row execute procedure public.set_updated_at();
