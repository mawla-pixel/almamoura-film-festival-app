create table public.vote_pricing (
  currency text primary key check (currency in ('AED', 'USD')),
  unit_amount_minor integer not null check (unit_amount_minor > 0),
  is_enabled boolean not null default true,
  updated_at timestamptz not null default now()
);

alter table public.vote_pricing enable row level security;
revoke all on table public.vote_pricing from anon, authenticated;
grant select on public.vote_pricing to anon, authenticated;

create policy "Vote pricing is publicly readable"
  on public.vote_pricing
  for select
  to anon, authenticated
  using (is_enabled);

insert into public.vote_pricing (currency, unit_amount_minor)
values
  ('AED', 1850),
  ('USD', 500)
on conflict (currency) do update
set
  unit_amount_minor = excluded.unit_amount_minor,
  is_enabled = true,
  updated_at = now();

update public.vote_bundles
set
  price = case id
    when 'single' then 18.50
    when 'five' then 92.50
    when 'ten' then 185.00
  end,
  updated_at = now()
where id in ('single', 'five', 'ten');

alter table public.film_vote_payments
  alter column bundle_id drop not null,
  add column unit_amount_minor integer;

update public.film_vote_payments
set unit_amount_minor = round(amount * 100 / votes)::integer
where unit_amount_minor is null;

alter table public.film_vote_payments
  alter column unit_amount_minor set not null,
  drop constraint film_vote_payments_currency_check,
  drop constraint film_vote_payments_votes_check,
  add constraint film_vote_payments_currency_check
    check (currency in ('AED', 'USD')),
  add constraint film_vote_payments_votes_check
    check (votes between 1 and 100),
  add constraint film_vote_payments_unit_amount_check
    check (unit_amount_minor > 0),
  add constraint film_vote_payments_total_matches_unit_amount_check
    check (amount * 100 = unit_amount_minor * votes);
