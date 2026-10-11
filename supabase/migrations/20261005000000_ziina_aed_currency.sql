-- Keep bundle amounts unchanged and charge them in AED.
update public.vote_bundles
set currency = 'AED', updated_at = now()
where id in ('single', 'five', 'ten');

alter table public.vote_bundles
  alter column currency set default 'AED';
