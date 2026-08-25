-- Öffentliche Hallen- und Kontaktdaten, bearbeitbar ausschließlich durch Admins.
create table public.club_contact_info (
  id boolean primary key default true check (id),
  club_name text not null,
  training_address text not null,
  contact_name text not null,
  phone text not null,
  email text not null,
  updated_at timestamptz not null default now()
);

insert into public.club_contact_info (
  club_name,
  training_address,
  contact_name,
  phone,
  email
) values (
  'KSC Olympia Graben-Neudorf',
  E'Friedrichstaler Str. 25\n76676 Graben-Neudorf',
  'Reinhold Kessel',
  '07255 5960',
  'KSCOlympiaGN@gmail.com'
);

alter table public.club_contact_info enable row level security;

create policy "Everyone can read club contact information"
on public.club_contact_info for select
to anon, authenticated
using (true);

create policy "Admins can update club contact information"
on public.club_contact_info for update
to authenticated
using (public.is_admin())
with check (public.is_admin());

grant select on public.club_contact_info to anon, authenticated;
grant update on public.club_contact_info to authenticated;

create trigger club_contact_info_set_updated_at
  before update on public.club_contact_info
  for each row execute procedure public.set_updated_at();
