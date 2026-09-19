begin;
-- One transaction for the entire person editor. Ordinary clients cannot bypass
-- the permission checks by sending privileged fields along with training groups.
create function public.save_person_settings(
 target_user_id uuid, expected_updated_at timestamptz, assigned_groups text[],
 trainer boolean default null, organization boolean default null,
 administrator boolean default null, review_applications boolean default null,
 revoke_access boolean default false
) returns void language plpgsql security definer set search_path='' as $$
declare p public.profiles; actor_admin boolean; groups text[];
begin
 actor_admin := public.is_admin();
 if not actor_admin and not public.can_review_memberships() then
   raise exception 'not_authorized'; end if;
 if revoke_access is null or assigned_groups is null then raise exception 'invalid_settings'; end if;
 if not actor_admin and (trainer is not null or organization is not null or
   administrator is not null or review_applications is not null or revoke_access) then
   raise exception 'admin_required'; end if;
 if actor_admin and (trainer is null or organization is null or
   administrator is null or review_applications is null) then raise exception 'invalid_settings'; end if;
 if exists(select 1 from unnest(assigned_groups) g
   where g is null or g not in ('Männer','Jugend','Bambinis')) then raise exception 'invalid_training_group'; end if;
 select coalesce(array_agg(g order by g),array[]::text[]) into groups
   from (select distinct unnest(assigned_groups) g) s;
 select * into p from public.profiles where id=target_user_id for update;
 if not found then raise exception 'profile_not_found'; end if;
 if expected_updated_at is null or p.updated_at is distinct from expected_updated_at then
   raise exception 'settings_changed'; end if;
 if p.membership_status<>'approved' or p.role='fan' then raise exception 'approved_membership_required'; end if;
 if target_user_id=auth.uid() and actor_admin and (not administrator or revoke_access) then
   raise exception 'cannot_change_own_role'; end if;
 if actor_admin and review_applications and not organization and not administrator then
   raise exception 'organization_required'; end if;

 if revoke_access then
   update public.profiles set role='fan',membership_status='not_requested',
     is_trainer=false,is_organization=false,can_respond_training=false,training_group=null
   where id=target_user_id;
   delete from public.profile_training_groups where user_id=target_user_id;
   delete from public.membership_reviewers where user_id=target_user_id;
   return;
 end if;
 if actor_admin then
   update public.profiles set is_trainer=trainer,is_organization=organization,
     role=case when administrator then 'admin' when trainer then 'trainer'
       when organization then 'organization' else 'member' end
   where id=target_user_id;
   if organization and review_applications then
     insert into public.membership_reviewers(user_id) values(target_user_id) on conflict do nothing;
   else
     delete from public.membership_reviewers where user_id=target_user_id;
   end if;
 end if;
 delete from public.profile_training_groups where user_id=target_user_id;
 insert into public.profile_training_groups(user_id,group_name)
   select target_user_id,unnest(groups);
 update public.profiles set can_respond_training=cardinality(groups)>0,training_group=groups[1]
 where id=target_user_id;
end $$;
revoke all on function public.save_person_settings(uuid,timestamptz,text[],boolean,boolean,boolean,boolean,boolean) from public;
grant execute on function public.save_person_settings(uuid,timestamptz,text[],boolean,boolean,boolean,boolean,boolean) to authenticated;
commit;
