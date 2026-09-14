-- Allow staff to record actual visits that predate the app request.
begin;
create or replace function public.manage_trial_training(
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
commit;
