begin;
create table public.membership_reviewers (
 user_id uuid primary key references public.profiles(id) on delete cascade
);
alter table public.membership_reviewers enable row level security;
create policy "Admin manages membership reviewers" on public.membership_reviewers
 for all to authenticated using (public.is_admin()) with check (public.is_admin());
grant select, insert, delete on public.membership_reviewers to authenticated;

create function public.can_process_membership_applications() returns boolean
language sql stable security definer set search_path = '' as $$
 select public.is_admin() or exists(select 1 from public.profiles p
 join public.membership_reviewers r on r.user_id=p.id
 where p.id=auth.uid() and p.role='organization' and p.membership_status='approved');
$$;
revoke all on function public.can_process_membership_applications() from public;
grant execute on function public.can_process_membership_applications() to authenticated;

create table public.membership_applications (
 user_id uuid primary key references public.profiles(id) on delete cascade,
 first_name text not null, last_name text not null, email text not null,
 status text not null default 'received' check(status in ('received','processing','approved','rejected')),
 assigned_to uuid references public.profiles(id) on delete set null,
 submitted_at timestamptz not null default now(), decided_at timestamptz,
 annual_fee_eur integer not null default 70 check(annual_fee_eur=70)
);
alter table public.membership_applications enable row level security;
create policy "Applicants and designated reviewers read applications"
 on public.membership_applications for select to authenticated
 using (user_id=auth.uid() or public.can_process_membership_applications());
grant select on public.membership_applications to authenticated;

-- Preserve already submitted applications; do not silently discard pending users.
insert into public.membership_applications(user_id,first_name,last_name,email,submitted_at)
 select p.id,coalesce(p.first_name,''),coalesce(p.last_name,''),coalesce(u.email,''),p.created_at
 from public.profiles p join auth.users u on u.id=p.id
 where p.role='member' and p.membership_status='pending';

create or replace function public.request_membership() returns void
language plpgsql security definer set search_path = '' as $$
declare p public.profiles; contact_email text;
begin
 select * into p from public.profiles where id=auth.uid() for update;
 if p.id is null or p.role <> 'fan' or p.membership_status not in ('not_requested','rejected') then
   raise exception 'membership_request_not_allowed'; end if;
 select email into contact_email from auth.users where id=auth.uid();
 if nullif(btrim(p.first_name),'') is null or nullif(btrim(p.last_name),'') is null
   or nullif(contact_email,'') is null then raise exception 'profile_incomplete'; end if;
 insert into public.membership_applications(user_id,first_name,last_name,email)
 values(p.id,p.first_name,p.last_name,contact_email)
 on conflict(user_id) do update set first_name=excluded.first_name,last_name=excluded.last_name,
 email=excluded.email,status='received',assigned_to=null,submitted_at=now(),decided_at=null;
 update public.profiles set role='member',membership_status='pending' where id=p.id;
end $$;

create function public.claim_membership_application(target_user_id uuid) returns void
language plpgsql security definer set search_path = '' as $$
begin
 if not public.can_process_membership_applications() then raise exception 'not_authorized'; end if;
 update public.membership_applications set status='processing',assigned_to=auth.uid()
 where user_id=target_user_id and status in ('received','processing')
 and (assigned_to is null or assigned_to=auth.uid() or public.is_admin());
 if not found then raise exception 'already_assigned_or_closed'; end if;
end $$;
revoke all on function public.claim_membership_application(uuid) from public;
grant execute on function public.claim_membership_application(uuid) to authenticated;

create or replace function public.review_membership_request(target_user_id uuid, approve boolean)
returns void language plpgsql security definer set search_path = '' as $$
begin
 if not public.can_process_membership_applications() then raise exception 'not_authorized'; end if;
 update public.membership_applications set status=case when approve then 'approved' else 'rejected' end,
 decided_at=now() where user_id=target_user_id and status='processing'
 and (assigned_to=auth.uid() or public.is_admin());
 if not found then raise exception 'claim_application_first'; end if;
 update public.profiles set role=case when approve then 'member' else 'fan' end,
 membership_status=case when approve then 'approved' else 'rejected' end,
 membership_approved_at=case when approve then now() else null end,membership_welcome_seen_at=null
 where id=target_user_id and membership_status='pending';
 if not found then raise exception 'membership_request_not_found'; end if;
end $$;
drop policy if exists "Trainers can read pending membership requests" on public.profiles;
-- Existing can_review_memberships() is intentionally unchanged: training rights depend on it.
commit;
