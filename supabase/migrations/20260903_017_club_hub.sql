-- Interaktiver Vereinsbereich fuer bestaetigte Vereinsmitglieder.

-- Eigene Hilfsfunktionen halten die RLS-Regeln lesbar und vermeiden rekursive
-- Abfragen auf public.profiles.
create or replace function public.can_access_club_hub()
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
      and role in ('member', 'trainer', 'organization', 'admin')
  );
$$;

create or replace function public.can_manage_club_hub()
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
      and role in ('trainer', 'organization', 'admin')
  );
$$;

revoke all on function public.can_access_club_hub() from public;
revoke all on function public.can_manage_club_hub() from public;
grant execute on function public.can_access_club_hub() to authenticated;
grant execute on function public.can_manage_club_hub() to authenticated;

-- Vereinsveranstaltungen und Helferdienste ---------------------------------
create table public.club_events (
  id bigint generated always as identity primary key,
  title text not null check (char_length(btrim(title)) between 2 and 120),
  description text check (description is null or char_length(description) <= 4000),
  event_type text not null default 'club'
    check (event_type in ('club', 'social', 'competition', 'work_assignment')),
  location text check (location is null or char_length(location) <= 240),
  starts_at timestamptz not null,
  ends_at timestamptz,
  registration_deadline timestamptz,
  participant_limit integer check (participant_limit is null or participant_limit > 0),
  helper_slots integer not null default 0 check (helper_slots >= 0),
  is_published boolean not null default true,
  created_by uuid not null references public.profiles(id) on delete restrict,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (ends_at is null or ends_at > starts_at),
  check (registration_deadline is null or registration_deadline <= starts_at)
);

create index club_events_starts_at_idx on public.club_events (starts_at);
create index club_events_published_starts_at_idx
  on public.club_events (is_published, starts_at);

alter table public.club_events enable row level security;

create policy "Club members can read published events"
on public.club_events for select to authenticated
using (
  public.can_access_club_hub()
  and (is_published or public.can_manage_club_hub())
);

create policy "Club staff can create events"
on public.club_events for insert to authenticated
with check (
  public.can_manage_club_hub()
  and created_by = auth.uid()
);

create policy "Club staff can update events"
on public.club_events for update to authenticated
using (public.can_manage_club_hub())
with check (public.can_manage_club_hub());

create policy "Club staff can delete events"
on public.club_events for delete to authenticated
using (public.can_manage_club_hub());

grant select, insert, update, delete on public.club_events to authenticated;
grant usage, select on sequence public.club_events_id_seq to authenticated;

create trigger club_events_set_updated_at
  before update on public.club_events
  for each row execute procedure public.set_updated_at();

create table public.club_event_registrations (
  event_id bigint not null references public.club_events(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  attendance_status text not null default 'attending'
    check (attendance_status in ('attending', 'not_attending')),
  is_helper boolean not null default false,
  note text check (note is null or char_length(note) <= 500),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key (event_id, user_id),
  check (attendance_status = 'attending' or not is_helper)
);

create index club_event_registrations_user_idx
  on public.club_event_registrations (user_id);

alter table public.club_event_registrations enable row level security;

create policy "Club members can read event registrations"
on public.club_event_registrations for select to authenticated
using (public.can_access_club_hub());

create policy "Club members can create own event registration"
on public.club_event_registrations for insert to authenticated
with check (
  public.can_access_club_hub()
  and user_id = auth.uid()
  and exists (
    select 1
    from public.club_events event
    where event.id = event_id
      and event.is_published
      and (
        event.registration_deadline is null
        or event.registration_deadline >= now()
      )
      and (not is_helper or event.helper_slots > 0)
  )
);

create policy "Club members can update own event registration"
on public.club_event_registrations for update to authenticated
using (
  public.can_access_club_hub()
  and user_id = auth.uid()
)
with check (
  public.can_access_club_hub()
  and user_id = auth.uid()
  and exists (
    select 1
    from public.club_events event
    where event.id = event_id
      and event.is_published
      and (
        event.registration_deadline is null
        or event.registration_deadline >= now()
      )
      and (not is_helper or event.helper_slots > 0)
  )
);

create policy "Club members can delete own event registration"
on public.club_event_registrations for delete to authenticated
using (
  public.can_access_club_hub()
  and user_id = auth.uid()
);

grant select, insert, update, delete
on public.club_event_registrations to authenticated;

create trigger club_event_registrations_set_updated_at
  before update on public.club_event_registrations
  for each row execute procedure public.set_updated_at();

-- Umfragen -----------------------------------------------------------------
create table public.club_polls (
  id bigint generated always as identity primary key,
  question text not null check (char_length(btrim(question)) between 2 and 240),
  description text check (description is null or char_length(description) <= 2000),
  allow_multiple boolean not null default false,
  closes_at timestamptz,
  is_published boolean not null default true,
  created_by uuid not null references public.profiles(id) on delete restrict,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index club_polls_published_closes_at_idx
  on public.club_polls (is_published, closes_at);

alter table public.club_polls enable row level security;

create policy "Club members can read published polls"
on public.club_polls for select to authenticated
using (
  public.can_access_club_hub()
  and (is_published or public.can_manage_club_hub())
);

create policy "Club staff can create polls"
on public.club_polls for insert to authenticated
with check (
  public.can_manage_club_hub()
  and created_by = auth.uid()
);

create policy "Club staff can update polls"
on public.club_polls for update to authenticated
using (public.can_manage_club_hub())
with check (public.can_manage_club_hub());

create policy "Club staff can delete polls"
on public.club_polls for delete to authenticated
using (public.can_manage_club_hub());

grant select, insert, update, delete on public.club_polls to authenticated;
grant usage, select on sequence public.club_polls_id_seq to authenticated;

create trigger club_polls_set_updated_at
  before update on public.club_polls
  for each row execute procedure public.set_updated_at();

create table public.club_poll_options (
  id bigint generated always as identity primary key,
  poll_id bigint not null references public.club_polls(id) on delete cascade,
  label text not null check (char_length(btrim(label)) between 1 and 160),
  sort_order integer not null default 0,
  created_at timestamptz not null default now(),
  unique (poll_id, id),
  unique (poll_id, label)
);

create index club_poll_options_order_idx
  on public.club_poll_options (poll_id, sort_order, id);

alter table public.club_poll_options enable row level security;

create policy "Club members can read poll options"
on public.club_poll_options for select to authenticated
using (
  public.can_access_club_hub()
  and exists (
    select 1 from public.club_polls poll
    where poll.id = poll_id
      and (poll.is_published or public.can_manage_club_hub())
  )
);

create policy "Club staff can create poll options"
on public.club_poll_options for insert to authenticated
with check (public.can_manage_club_hub());

create policy "Club staff can update poll options"
on public.club_poll_options for update to authenticated
using (public.can_manage_club_hub())
with check (public.can_manage_club_hub());

create policy "Club staff can delete poll options"
on public.club_poll_options for delete to authenticated
using (public.can_manage_club_hub());

grant select, insert, update, delete on public.club_poll_options to authenticated;
grant usage, select on sequence public.club_poll_options_id_seq to authenticated;

create table public.club_poll_votes (
  poll_id bigint not null references public.club_polls(id) on delete cascade,
  option_id bigint not null,
  user_id uuid not null references public.profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (poll_id, user_id, option_id),
  foreign key (poll_id, option_id)
    references public.club_poll_options(poll_id, id) on delete cascade
);

create index club_poll_votes_option_idx
  on public.club_poll_votes (poll_id, option_id);
create index club_poll_votes_user_idx
  on public.club_poll_votes (user_id);

alter table public.club_poll_votes enable row level security;

create policy "Club members can read poll votes"
on public.club_poll_votes for select to authenticated
using (public.can_access_club_hub());

create policy "Club members can create own poll votes"
on public.club_poll_votes for insert to authenticated
with check (
  public.can_access_club_hub()
  and user_id = auth.uid()
  and exists (
    select 1 from public.club_polls poll
    where poll.id = poll_id
      and poll.is_published
      and (poll.closes_at is null or poll.closes_at > now())
  )
);

create policy "Club members can update own poll votes"
on public.club_poll_votes for update to authenticated
using (
  public.can_access_club_hub()
  and user_id = auth.uid()
)
with check (
  public.can_access_club_hub()
  and user_id = auth.uid()
  and exists (
    select 1 from public.club_polls poll
    where poll.id = poll_id
      and poll.is_published
      and (poll.closes_at is null or poll.closes_at > now())
  )
);

create policy "Club members can delete own poll votes"
on public.club_poll_votes for delete to authenticated
using (
  public.can_access_club_hub()
  and user_id = auth.uid()
  and exists (
    select 1 from public.club_polls poll
    where poll.id = poll_id
      and poll.is_published
      and (poll.closes_at is null or poll.closes_at > now())
  )
);

grant select, insert, update, delete on public.club_poll_votes to authenticated;

-- Stellt bei Einfachauswahl sicher, dass pro Mitglied nur eine Option
-- gespeichert werden kann. Bei Mehrfachauswahl bleiben mehrere Zeilen erlaubt.
create or replace function public.validate_club_poll_vote()
returns trigger
language plpgsql
security definer set search_path = ''
as $$
declare
  multiple_allowed boolean;
  poll_published boolean;
  poll_closes_at timestamptz;
begin
  select allow_multiple, is_published, closes_at
  into multiple_allowed, poll_published, poll_closes_at
  from public.club_polls
  where id = new.poll_id;

  if not found then
    raise exception 'club_poll_not_found';
  end if;

  if not poll_published or (poll_closes_at is not null and poll_closes_at <= now()) then
    raise exception 'club_poll_closed';
  end if;

  if not multiple_allowed then
    if tg_op = 'INSERT' and exists (
      select 1 from public.club_poll_votes
      where poll_id = new.poll_id and user_id = new.user_id
    ) then
      raise exception 'club_poll_single_vote_only';
    end if;

    if tg_op = 'UPDATE' and exists (
      select 1 from public.club_poll_votes
      where poll_id = new.poll_id
        and user_id = new.user_id
        and not (
          poll_id = old.poll_id
          and user_id = old.user_id
          and option_id = old.option_id
        )
    ) then
      raise exception 'club_poll_single_vote_only';
    end if;
  end if;

  return new;
end;
$$;

revoke all on function public.validate_club_poll_vote() from public;

create trigger club_poll_votes_validate
  before insert or update on public.club_poll_votes
  for each row execute procedure public.validate_club_poll_vote();

-- Schwarzes Brett ----------------------------------------------------------
create table public.club_board_posts (
  id bigint generated always as identity primary key,
  title text not null check (char_length(btrim(title)) between 2 and 120),
  body text not null check (char_length(btrim(body)) between 2 and 3000),
  category text not null default 'general'
    check (category in ('general', 'rides', 'offer', 'wanted', 'lost_found')),
  is_pinned boolean not null default false,
  expires_at timestamptz,
  created_by uuid not null references public.profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index club_board_posts_created_at_idx
  on public.club_board_posts (created_at desc);
create index club_board_posts_expires_at_idx
  on public.club_board_posts (expires_at);

alter table public.club_board_posts enable row level security;

create policy "Club members can read board posts"
on public.club_board_posts for select to authenticated
using (
  public.can_access_club_hub()
  and (
    expires_at is null
    or expires_at > now()
    or created_by = auth.uid()
    or public.can_manage_club_hub()
  )
);

create policy "Club members can create board posts"
on public.club_board_posts for insert to authenticated
with check (
  public.can_access_club_hub()
  and created_by = auth.uid()
  and (not is_pinned or public.can_manage_club_hub())
);

create policy "Authors and club staff can update board posts"
on public.club_board_posts for update to authenticated
using (
  public.can_manage_club_hub()
  or (
    public.can_access_club_hub()
    and created_by = auth.uid()
    and not is_pinned
  )
)
with check (
  public.can_manage_club_hub()
  or (
    public.can_access_club_hub()
    and created_by = auth.uid()
    and not is_pinned
  )
);

create policy "Authors and club staff can delete board posts"
on public.club_board_posts for delete to authenticated
using (
  public.can_manage_club_hub()
  or (
    public.can_access_club_hub()
    and created_by = auth.uid()
  )
);

grant select, insert, update, delete on public.club_board_posts to authenticated;
grant usage, select on sequence public.club_board_posts_id_seq to authenticated;

create trigger club_board_posts_set_updated_at
  before update on public.club_board_posts
  for each row execute procedure public.set_updated_at();

-- Persoenliche Benachrichtigungseinstellungen ------------------------------
create table public.club_notification_preferences (
  user_id uuid primary key references public.profiles(id) on delete cascade,
  events_enabled boolean not null default true,
  event_reminders_enabled boolean not null default true,
  helper_requests_enabled boolean not null default true,
  polls_enabled boolean not null default true,
  board_enabled boolean not null default true,
  news_enabled boolean not null default true,
  training_enabled boolean not null default true,
  league_enabled boolean not null default true,
  updated_at timestamptz not null default now()
);

alter table public.club_notification_preferences enable row level security;

create policy "Club members can read own notification preferences"
on public.club_notification_preferences for select to authenticated
using (
  public.can_access_club_hub()
  and user_id = auth.uid()
);

create policy "Club members can create own notification preferences"
on public.club_notification_preferences for insert to authenticated
with check (
  public.can_access_club_hub()
  and user_id = auth.uid()
);

create policy "Club members can update own notification preferences"
on public.club_notification_preferences for update to authenticated
using (
  public.can_access_club_hub()
  and user_id = auth.uid()
)
with check (
  public.can_access_club_hub()
  and user_id = auth.uid()
);

create policy "Club members can delete own notification preferences"
on public.club_notification_preferences for delete to authenticated
using (
  public.can_access_club_hub()
  and user_id = auth.uid()
);

grant select, insert, update, delete
on public.club_notification_preferences to authenticated;

create trigger club_notification_preferences_set_updated_at
  before update on public.club_notification_preferences
  for each row execute procedure public.set_updated_at();

-- Aenderungen erscheinen ohne manuelles Neuladen auf anderen Geraeten.
alter publication supabase_realtime add table public.club_events;
alter publication supabase_realtime add table public.club_event_registrations;
alter publication supabase_realtime add table public.club_polls;
alter publication supabase_realtime add table public.club_poll_options;
alter publication supabase_realtime add table public.club_poll_votes;
alter publication supabase_realtime add table public.club_board_posts;
