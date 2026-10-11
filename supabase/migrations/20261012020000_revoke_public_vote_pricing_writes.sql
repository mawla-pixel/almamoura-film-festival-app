revoke all on table public.vote_pricing, public.vote_bundles
  from anon, authenticated;

grant select on table public.vote_pricing, public.vote_bundles
  to anon, authenticated;
