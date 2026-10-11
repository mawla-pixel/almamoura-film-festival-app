drop policy if exists "Festival admins can read submissions"
  on public.festival_submissions;
create policy "Festival admins can read submissions"
  on public.festival_submissions
  for select
  to authenticated
  using (((select auth.jwt()) -> 'app_metadata' ->> 'role') = 'festival_admin');
