-- Eigene Vereinsbeitraege und die getrennte Rolle "Organisation".

alter table public.profiles drop constraint profiles_role_check;
alter table public.profiles add constraint profiles_role_check
  check (role in ('fan', 'member', 'trainer', 'organization', 'admin'));

create or replace function public.set_user_role(
  target_user_id uuid,
  new_role text
)
returns void
language plpgsql
security definer set search_path = ''
as $$
begin
  if not public.is_admin() then raise exception 'admin_required'; end if;
  if target_user_id = auth.uid() then raise exception 'cannot_change_own_role'; end if;
  if new_role not in ('fan', 'member', 'trainer', 'organization', 'admin') then
    raise exception 'invalid_role';
  end if;

  update public.profiles set
    role = new_role,
    membership_status = case
      when new_role = 'fan' then 'not_requested'
      else 'approved'
    end
  where id = target_user_id;
  if not found then raise exception 'profile_not_found'; end if;
end;
$$;
revoke all on function public.set_user_role(uuid, text) from public;
grant execute on function public.set_user_role(uuid, text) to authenticated;

create or replace function public.can_publish_news()
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (
    select 1 from public.profiles
    where id = auth.uid() and membership_status = 'approved'
      and role in ('trainer', 'organization', 'admin')
  );
$$;
revoke all on function public.can_publish_news() from public;
grant execute on function public.can_publish_news() to anon, authenticated;

create table public.club_news_posts (
  id bigint generated always as identity primary key,
  title text not null check (char_length(btrim(title)) between 1 and 120),
  body text not null check (char_length(btrim(body)) between 1 and 4000),
  image_path text,
  created_by uuid not null references public.profiles(id) on delete cascade,
  published_at timestamptz not null default now(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.club_news_posts enable row level security;
create policy "Everyone can read club news"
on public.club_news_posts for select to anon, authenticated using (true);
create policy "Publishers can create club news"
on public.club_news_posts for insert to authenticated
with check (public.can_publish_news() and created_by = auth.uid());
create policy "Publishers can update own club news"
on public.club_news_posts for update to authenticated
using (
  public.is_admin() or
  (public.can_publish_news() and created_by = auth.uid())
)
with check (
  public.is_admin() or
  (public.can_publish_news() and created_by = auth.uid())
);
create policy "Publishers can delete own club news"
on public.club_news_posts for delete to authenticated
using (
  public.is_admin() or
  (public.can_publish_news() and created_by = auth.uid())
);
grant select on public.club_news_posts to anon, authenticated;
grant insert, update, delete on public.club_news_posts to authenticated;
grant usage, select on sequence public.club_news_posts_id_seq to authenticated;
create trigger club_news_posts_set_updated_at before update
on public.club_news_posts for each row execute procedure public.set_updated_at();

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'news-images',
  'news-images',
  true,
  8388608,
  array['image/jpeg', 'image/png', 'image/webp']
)
on conflict (id) do update set
  public = excluded.public,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

create policy "Everyone can view news images"
on storage.objects for select to anon, authenticated
using (bucket_id = 'news-images');
create policy "Publishers can upload news images"
on storage.objects for insert to authenticated
with check (
  bucket_id = 'news-images' and public.can_publish_news()
  and split_part(name, '/', 1) = auth.uid()::text
);
create policy "Publishers can update own news images"
on storage.objects for update to authenticated
using (
  bucket_id = 'news-images' and
  (public.is_admin() or split_part(name, '/', 1) = auth.uid()::text)
)
with check (
  bucket_id = 'news-images' and
  (public.is_admin() or split_part(name, '/', 1) = auth.uid()::text)
);
create policy "Publishers can delete own news images"
on storage.objects for delete to authenticated
using (
  bucket_id = 'news-images' and
  (public.is_admin() or split_part(name, '/', 1) = auth.uid()::text)
);
