-- Serverseitige Speicherung und regelmaessige Erneuerung des Instagram-Tokens.

create table public.instagram_token_state (
  id boolean primary key default true check (id),
  access_token text not null,
  refreshed_at timestamptz not null default now(),
  expires_at timestamptz
);

alter table public.instagram_token_state enable row level security;
revoke all on public.instagram_token_state from anon, authenticated;
grant select, insert, update on public.instagram_token_state to service_role;

create extension if not exists pg_cron with schema pg_catalog;
create extension if not exists pg_net with schema extensions;

select cron.schedule(
  'refresh-instagram-token-weekly',
  '0 4 * * 1',
  $$
  select net.http_post(
    url := 'https://vsbpugvxukxhsptvpzzs.supabase.co/functions/v1/instagram-feed',
    headers := jsonb_build_object('Content-Type', 'application/json'),
    body := '{}'::jsonb
  );
  $$
);
