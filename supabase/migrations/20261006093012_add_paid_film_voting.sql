create table if not exists public.vote_bundles (
  id text primary key,
  votes integer not null check (votes > 0),
  label text not null,
  description text not null,
  price numeric(10, 2) not null check (price > 0),
  currency text not null default 'AED' check (char_length(currency) = 3),
  is_best_value boolean not null default false,
  sort_order integer not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

insert into public.vote_bundles (
  id, votes, label, description, price, currency, is_best_value, sort_order
)
values
  ('single', 1, '1 vote', 'Perfect for one favorite film', 5.00, 'AED', false, 1),
  ('five', 5, '5 votes', 'Vote across multiple categories', 25.00, 'AED', true, 2),
  ('ten', 10, '10 votes', 'For dedicated festival supporters', 50.00, 'AED', false, 3)
on conflict (id) do update set
  votes = excluded.votes,
  label = excluded.label,
  description = excluded.description,
  price = excluded.price,
  currency = excluded.currency,
  is_best_value = excluded.is_best_value,
  sort_order = excluded.sort_order,
  updated_at = now();

alter table public.vote_bundles enable row level security;
grant select on public.vote_bundles to anon, authenticated;
drop policy if exists "Vote bundles are publicly readable" on public.vote_bundles;
create policy "Vote bundles are publicly readable"
  on public.vote_bundles for select to anon, authenticated using (true);

create table if not exists public.film_vote_payments (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  film_id uuid not null references public.festival_submissions(id) on delete restrict,
  bundle_id text not null references public.vote_bundles(id),
  operation_id uuid not null unique,
  ziina_payment_intent_id text unique,
  votes integer not null check (votes > 0),
  amount numeric(10, 2) not null check (amount > 0),
  currency text not null check (currency = 'AED'),
  status text not null default 'pending'
    check (status in ('pending', 'completed', 'failed', 'canceled')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.film_vote_payments enable row level security;
revoke all on public.film_vote_payments from anon, authenticated;
grant select on public.film_vote_payments to authenticated;
drop policy if exists "Users can read own film vote payments"
  on public.film_vote_payments;
create policy "Users can read own film vote payments"
  on public.film_vote_payments for select to authenticated
  using ((select auth.uid()) = user_id);

create index if not exists film_vote_payments_film_status_idx
  on public.film_vote_payments (film_id, status);
create index if not exists film_vote_payments_user_created_idx
  on public.film_vote_payments (user_id, created_at desc);

create or replace function public.set_film_vote_payments_updated_at()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists film_vote_payments_set_updated_at
  on public.film_vote_payments;
create trigger film_vote_payments_set_updated_at
before update on public.film_vote_payments
for each row execute function public.set_film_vote_payments_updated_at();

create or replace view public.public_voting_films with (security_barrier = true) as
select
  s.id,
  s.project_title as title,
  array[s.submission_categories]::text[] as project_types,
  ''::text as director,
  array[]::text[] as countries_of_origin,
  0::numeric as rating,
  0::integer as duration_minutes,
  '2026'::text as year,
  coalesce(s.project_data ->> 'synopsis', '') as synopsis,
  coalesce(s.project_data ->> 'genres', '') as tags,
  s.project_data ->> 'trailer_url' as trailer_url,
  count(p.id)::bigint as audience_votes
from public.festival_submissions s
left join public.film_vote_payments p
  on p.film_id = s.id and p.status = 'completed'
group by s.id, s.project_title, s.submission_categories, s.project_data;

revoke all on public.public_voting_films from anon, authenticated;
grant select on public.public_voting_films to anon, authenticated;
