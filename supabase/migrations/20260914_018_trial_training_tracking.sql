-- One trial-training record per authenticated account, across all groups.
-- Existing anonymous requests remain visible to staff; do not match by email.
begin;
alter table public.trial_training_requests
  add column user_id uuid references auth.users(id) on delete restrict;
create unique index trial_training_account_unique
  on public.trial_training_requests(user_id) where user_id is not null;

drop policy "Anyone can request a trial training" on public.trial_training_requests;
drop policy "Club staff can update trial requests" on public.trial_training_requests;
revoke insert, update, delete on public.trial_training_requests from anon, authenticated;
create policy "Applicants can read their trial request"
  on public.trial_training_requests for select to authenticated
  using (user_id = auth.uid());

create table public.trial_training_visits (
  id bigint generated always as identity primary key,
  request_id bigint not null references public.trial_training_requests(id),
  attended_on date not null,
  recorded_by uuid not null references auth.users(id),
  created_at timestamptz not null default now(),
  voided_at timestamptz,
  voided_by uuid references auth.users(id)
);
create unique index trial_training_visit_day_unique
  on public.trial_training_visits(request_id, attended_on) where voided_at is null;
alter table public.trial_training_visits enable row level security;
grant select on public.trial_training_visits to authenticated;
revoke insert, update, delete on public.trial_training_visits from anon, authenticated;
create policy "Trial visits visible to applicant and staff"
  on public.trial_training_visits for select to authenticated
  using (public.can_review_memberships() or exists (
    select 1 from public.trial_training_requests r
    where r.id = request_id and r.user_id = auth.uid()
  ));

create function public.request_trial_training(
  applicant_name text, requested_group text, applicant_phone text, applicant_note text
) returns void language plpgsql security definer set search_path = '' as $$
begin
  if auth.uid() is null then raise exception 'Bitte zuerst anmelden.'; end if;
  insert into public.trial_training_requests
    (user_id, full_name, email, training_group, phone, note)
  values (auth.uid(), btrim(applicant_name),
    (select email from auth.users where id = auth.uid()),
    requested_group, nullif(btrim(applicant_phone), ''), nullif(btrim(applicant_note), ''));
exception when unique_violation then
  raise exception 'Für dein Konto besteht bereits eine Probetraining-Anfrage.';
end;
$$;

-- Lock the parent row for every mutation: concurrent trainers cannot exceed 4.
create function public.manage_trial_training(
  target_request_id bigint, action text,
  visit_date date default null, target_visit_id bigint default null
) returns void language plpgsql security definer set search_path = '' as $$
declare
  request public.trial_training_requests;
  visit_count integer;
begin
  if not public.can_review_memberships() then
    raise exception 'Nur Trainer und Admins dürfen Probetrainings bearbeiten.';
  end if;
  select * into request from public.trial_training_requests
    where id = target_request_id for update;
  if not found then raise exception 'Anfrage nicht gefunden.'; end if;
  select count(*) into visit_count from public.trial_training_visits
    where request_id = request.id and voided_at is null;
  if action = 'approve' then
    if request.user_id is null then
      raise exception 'Alte Anfrage ohne Konto: Bitte angemeldet neu anfragen.';
    end if;
    update public.trial_training_requests
      set status = case when visit_count >= 4 then 'completed' else 'contacted' end
      where id = request.id;
  elsif action = 'reject' then
    update public.trial_training_requests set status = 'cancelled' where id = request.id;
  elsif action = 'attend' then
    if request.user_id is null or request.status <> 'contacted' then
      raise exception 'Die Anfrage muss zuerst bestätigt werden.';
    end if;
    if visit_count >= 4 then raise exception 'Alle vier Probetrainings sind verbraucht.'; end if;
    if visit_date is null or visit_date > (now() at time zone 'Europe/Berlin')::date
      or visit_date < date '2000-01-01' then
      raise exception 'Bitte einen vergangenen oder heutigen Termin ab dem Jahr 2000 wählen.';
    end if;
    insert into public.trial_training_visits(request_id, attended_on, recorded_by)
      values(request.id, visit_date, auth.uid());
    if visit_count = 3 then
      update public.trial_training_requests set status = 'completed' where id = request.id;
    end if;
  elsif action = 'undo' then
    update public.trial_training_visits set voided_at = now(), voided_by = auth.uid()
      where id = target_visit_id and request_id = request.id and voided_at is null;
    if not found then raise exception 'Teilnahme wurde bereits korrigiert.'; end if;
    if request.status = 'completed' then
      update public.trial_training_requests set status = 'contacted' where id = request.id;
    end if;
  else raise exception 'Unbekannte Aktion.';
  end if;
exception when unique_violation then
  raise exception 'Für diesen Tag wurde bereits eine Teilnahme erfasst.';
end;
$$;
revoke all on function public.request_trial_training(text,text,text,text) from public, anon;
revoke all on function public.manage_trial_training(bigint,text,date,bigint) from public, anon;
grant execute on function public.request_trial_training(text,text,text,text) to authenticated;
grant execute on function public.manage_trial_training(bigint,text,date,bigint) to authenticated;
commit;
