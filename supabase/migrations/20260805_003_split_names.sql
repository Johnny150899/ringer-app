alter table public.profiles
  add column first_name text not null default '',
  add column last_name text not null default '',
  drop column full_name;

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer set search_path = ''
as $$
declare
  given_first_name text := coalesce(new.raw_user_meta_data ->> 'first_name', '');
  given_last_name text := coalesce(new.raw_user_meta_data ->> 'last_name', '');
begin
  insert into public.profiles (
    id,
    first_name,
    last_name,
    role,
    membership_status
  )
  values (
    new.id,
    given_first_name,
    given_last_name,
    'fan',
    'not_requested'
  );
  return new;
end;
$$;

grant update (first_name, last_name) on public.profiles to authenticated;
