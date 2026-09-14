-- Probetraining, pflegbare Mitgliedervorteile und Einladungscode.

alter table public.profiles
  add column if not exists referral_code text unique;

update public.profiles
set referral_code = upper(substr(md5(id::text), 1, 8))
where referral_code is null;

alter table public.profiles
  alter column referral_code set default upper(substr(md5(gen_random_uuid()::text), 1, 8));

create table if not exists public.trial_training_requests (
  id bigint generated always as identity primary key,
  full_name text not null check (char_length(btrim(full_name)) between 3 and 120),
  email text not null check (char_length(btrim(email)) between 5 and 255),
  phone text,
  training_group text not null check (training_group in ('Männer', 'Jugend', 'Bambinis')),
  note text check (note is null or char_length(note) <= 1000),
  status text not null default 'open' check (status in ('open', 'contacted', 'completed', 'cancelled')),
  created_at timestamptz not null default now()
);

alter table public.trial_training_requests enable row level security;
create policy "Anyone can request a trial training"
on public.trial_training_requests for insert to anon, authenticated
with check (status = 'open');
create policy "Club staff can read trial requests"
on public.trial_training_requests for select to authenticated
using (public.can_review_memberships());
create policy "Club staff can update trial requests"
on public.trial_training_requests for update to authenticated
using (public.can_review_memberships()) with check (public.can_review_memberships());
grant insert on public.trial_training_requests to anon, authenticated;
grant select, update on public.trial_training_requests to authenticated;
grant usage, select on sequence public.trial_training_requests_id_seq to anon, authenticated;

create table if not exists public.member_benefits (
  id bigint generated always as identity primary key,
  title text not null check (char_length(btrim(title)) between 2 and 100),
  description text not null check (char_length(btrim(description)) between 2 and 500),
  partner_name text,
  active boolean not null default true,
  sort_order integer not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.member_benefits enable row level security;
create policy "Members can read active benefits"
on public.member_benefits for select to authenticated
using (
  active and exists (
    select 1 from public.profiles
    where id = auth.uid() and membership_status = 'approved' and role <> 'fan'
  )
);
create policy "Admins manage member benefits"
on public.member_benefits for all to authenticated
using (public.is_admin()) with check (public.is_admin());
grant select, insert, update, delete on public.member_benefits to authenticated;
grant usage, select on sequence public.member_benefits_id_seq to authenticated;
