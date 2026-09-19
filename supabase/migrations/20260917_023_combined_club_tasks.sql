begin;
alter table public.profiles add column is_trainer boolean not null default false,
 add column is_organization boolean not null default false;
update public.profiles set is_trainer=(role='trainer'),is_organization=(role='organization');
-- No UPDATE grant on the task columns: only the admin RPC may assign them.
create function public.set_profile_tasks(target_user_id uuid, trainer boolean, organization boolean)
returns void language plpgsql security definer set search_path='' as $$
begin
 if not public.is_admin() then raise exception 'admin_required'; end if;
 if trainer is null or organization is null then raise exception 'invalid_tasks'; end if;
 update public.profiles set is_trainer=trainer,is_organization=organization,
 role=case when role='admin' then 'admin' when trainer then 'trainer'
   when organization then 'organization' else 'member' end
 where id=target_user_id and membership_status='approved' and role<>'fan';
 if not found then raise exception 'approved_membership_required'; end if;
 if not organization then delete from public.membership_reviewers where user_id=target_user_id; end if;
end $$;
revoke all on function public.set_profile_tasks(uuid,boolean,boolean) from public;
grant execute on function public.set_profile_tasks(uuid,boolean,boolean) to authenticated;

-- Retain the legacy role as a compatibility projection; task flags are independent.
create or replace function public.set_user_role(target_user_id uuid,new_role text)
returns void language plpgsql security definer set search_path='' as $$
declare p public.profiles;
begin
 if not public.is_admin() then raise exception 'admin_required'; end if;
 if target_user_id=auth.uid() then raise exception 'cannot_change_own_role'; end if;
 if new_role is null or new_role not in ('fan','member','trainer','organization','admin') then raise exception 'invalid_role'; end if;
 select * into p from public.profiles where id=target_user_id for update;
 if not found then raise exception 'profile_not_found'; end if;
 -- Membership admission belongs to the reviewed application workflow.
 if new_role<>'fan' and p.membership_status<>'approved' then raise exception 'approved_membership_required'; end if;
 update public.profiles set
 is_trainer=case when new_role='fan' then false when new_role='trainer' then true else is_trainer end,
 is_organization=case when new_role='fan' then false when new_role='organization' then true else is_organization end,
 role=case when new_role in ('fan','admin') then new_role
   when new_role='trainer' or is_trainer then 'trainer'
   when new_role='organization' or is_organization then 'organization' else 'member' end,
 membership_status=case when new_role='fan' then 'not_requested' else membership_status end,
 can_respond_training=case when new_role='fan' then false else can_respond_training end
 where id=target_user_id;
 if new_role='fan' then
   delete from public.membership_reviewers where user_id=target_user_id;
   delete from public.profile_training_groups where user_id=target_user_id;
 end if;
end $$;

create or replace function public.can_review_memberships() returns boolean
language sql stable security definer set search_path='' as $$
 select exists(select 1 from public.profiles where id=auth.uid()
 and membership_status='approved' and (is_trainer or role='admin'));
$$;
create or replace function public.can_publish_news() returns boolean
language sql stable security definer set search_path='' as $$
 select exists(select 1 from public.profiles where id=auth.uid()
 and membership_status='approved' and (is_trainer or is_organization or role='admin'));
$$;
create or replace function public.can_manage_club_hub() returns boolean
language sql stable security definer set search_path='' as $$
 select public.can_publish_news();
$$;
create or replace function public.can_process_membership_applications() returns boolean
language sql stable security definer set search_path='' as $$
 select public.is_admin() or exists(select 1 from public.profiles p
 join public.membership_reviewers r on r.user_id=p.id
 where p.id=auth.uid() and p.is_organization and p.membership_status='approved');
$$;
commit;
