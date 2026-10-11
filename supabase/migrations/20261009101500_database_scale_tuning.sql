create index if not exists film_vote_payments_bundle_id_idx
  on public.film_vote_payments (bundle_id);

drop index if exists public.public_voting_films_votes_idx;
create index if not exists public_voting_films_votes_title_id_idx
  on public.public_voting_films (audience_votes desc, title asc, id asc);

drop policy if exists "Festival admins can manage poster tracking"
  on public.festival_poster_tracking;
create policy "Festival admins can manage poster tracking"
  on public.festival_poster_tracking
  for all
  to authenticated
  using (((select auth.jwt()) -> 'app_metadata' ->> 'role') = 'festival_admin')
  with check (((select auth.jwt()) -> 'app_metadata' ->> 'role') = 'festival_admin');

revoke execute on function public.sync_festival_poster_catalogue()
  from public, anon, authenticated, service_role;
revoke execute on function public.rls_auto_enable()
  from public, anon, authenticated, service_role;
