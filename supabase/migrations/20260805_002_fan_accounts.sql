-- Neue Konten sind sofort aktive Fan-Konten. Eine Vereinsmitgliedschaft wird
-- getrennt beantragt und anschließend von einem Administrator bestätigt.
alter table public.profiles
  drop constraint profiles_role_check,
  drop constraint profiles_membership_status_check;

alter table public.profiles
  alter column role set default 'fan',
  alter column membership_status set default 'not_requested';

alter table public.profiles
  add constraint profiles_role_check
    check (role in ('fan', 'member', 'admin')),
  add constraint profiles_membership_status_check
    check (
      membership_status in ('not_requested', 'pending', 'approved', 'rejected')
    );

-- In der bisherigen Testphase angelegte, ungeprüfte Konten werden Fans.
update public.profiles
set role = 'fan', membership_status = 'not_requested'
where role = 'member' and membership_status = 'pending';

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer set search_path = ''
as $$
begin
  insert into public.profiles (
    id,
    full_name,
    role,
    membership_status
  )
  values (
    new.id,
    coalesce(new.raw_user_meta_data ->> 'full_name', ''),
    'fan',
    'not_requested'
  );
  return new;
end;
$$;

create or replace function public.request_membership()
returns void
language plpgsql
security definer set search_path = ''
as $$
begin
  update public.profiles
  set role = 'member', membership_status = 'pending'
  where id = auth.uid()
    and role = 'fan'
    and membership_status in ('not_requested', 'rejected');

  if not found then
    raise exception 'membership_request_not_allowed';
  end if;
end;
$$;

grant execute on function public.request_membership() to authenticated;
