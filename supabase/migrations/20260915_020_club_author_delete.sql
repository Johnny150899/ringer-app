-- Only the author or an admin may remove club content.
drop policy if exists "Club staff can delete polls" on public.club_polls;
create policy "Poll authors and admins can delete polls"
on public.club_polls for delete to authenticated
using (
  created_by = auth.uid()
  or exists (
    select 1 from public.profiles profile
    where profile.id = auth.uid() and profile.role = 'admin'
  )
);

drop policy if exists "Authors and club staff can delete board posts"
on public.club_board_posts;
create policy "Board authors and admins can delete posts"
on public.club_board_posts for delete to authenticated
using (
  created_by = auth.uid()
  or exists (
    select 1 from public.profiles profile
    where profile.id = auth.uid() and profile.role = 'admin'
  )
);
