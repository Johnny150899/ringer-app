-- Abweichungen fuer einen einzelnen Termin (Absage oder Hinweis).
create table public.training_occurrence_overrides (
  schedule_id bigint not null references public.weekly_training_schedule(id) on delete cascade,
  training_date date not null,
  is_cancelled boolean not null default false,
  note text,
  updated_by uuid references public.profiles(id) on delete set null,
  updated_at timestamptz not null default now(),
  primary key (schedule_id, training_date)
);

alter table public.training_occurrence_overrides enable row level security;
create policy "Members can read training changes"
on public.training_occurrence_overrides for select to authenticated
using (public.is_approved_member());
grant select on public.training_occurrence_overrides to authenticated;

create or replace function public.set_training_occurrence(
  target_schedule_id bigint,
  target_date date,
  cancelled boolean,
  new_note text default null
)
returns void language plpgsql security definer set search_path = '' as $$
begin
  if not public.can_review_memberships() then
    raise exception 'trainer_or_admin_required';
  end if;
  insert into public.training_occurrence_overrides
    (schedule_id, training_date, is_cancelled, note, updated_by)
  values
    (target_schedule_id, target_date, cancelled, nullif(btrim(new_note), ''), auth.uid())
  on conflict (schedule_id, training_date) do update set
    is_cancelled = excluded.is_cancelled,
    note = excluded.note,
    updated_by = auth.uid(),
    updated_at = now();
end;
$$;
revoke all on function public.set_training_occurrence(bigint, date, boolean, text) from public;
grant execute on function public.set_training_occurrence(bigint, date, boolean, text)
to authenticated;
