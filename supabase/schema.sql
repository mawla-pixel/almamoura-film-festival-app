-- ============================================================================
-- Almamoura Film Festival — Initial Supabase Schema
-- ============================================================================
--
-- Current scope:
--   - Public film catalogue
--   - Public vote bundle catalogue and authenticated Ziina purchases
--   - Permanent-user 1–5 star audience ratings
--   - Local-only guest mode
--
-- Guests may:
--   - Browse films
--   - Search and filter
--   - View film details
--   - Watch approved external media
--   - Read public bundle information
--
-- Guests may NOT:
--   - Create a Supabase anonymous session
--   - Rate films
--   - Vote
--   - Purchase bundles
--   - Create favorites or bookmarks
--   - Submit films
--   - Write data to Supabase
--
-- Important:
--   - Do not use supabase.auth.signInAnonymously() in Flutter.
--   - Do not use the service-role / secret key in Flutter.
--   - This file includes Ziina payment records but does not grant purchased
--     votes to film ballots. It does not create Storage, favorites, bookmarks,
--     profiles, or submission workflows.
--   - The current `votes` table represents 1–5 star audience ratings only.
--     Paid vote allocation to festival ballots remains a separate workflow:
--       1. film_ratings
--       2. festival_votes
--       3. payments / vote_credits
-- ============================================================================


-- ============================================================================
-- Required extensions
-- ============================================================================

create extension if not exists pgcrypto;


-- ============================================================================
-- Shared utility: automatic updated_at timestamps
-- ============================================================================

create or replace function public.set_updated_at()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;


-- ============================================================================
-- films
-- ============================================================================
--
-- Films are publicly readable so local-only guests, unauthenticated visitors,
-- and signed-in users can browse the catalogue.
--
-- Aggregate fields:
--   - audience_rating
--   - audience_rating_count
--
-- are display/cache values for now. They must NOT be directly writable by
-- Flutter clients. A later server-side function or trigger should calculate
-- them from submitted film ratings.
-- ============================================================================

create table if not exists public.films (
  id uuid primary key default gen_random_uuid(),

  -- Core catalogue metadata
  title text not null,
  slug text unique,
  category text not null,
  director text not null default '',
  country text not null default '',
  country_flag text not null default '',
  duration_minutes integer not null default 0
    check (duration_minutes >= 0),
  release_year integer not null default 2026
    check (release_year between 1888 and 2100),

  badge text not null default '',
  synopsis text not null default '',
  tags text[] not null default '{}',

  -- Public display/cache aggregates.
  -- Do not let mobile clients update these values directly.
  audience_rating numeric(3, 2) not null default 0
    check (audience_rating >= 0 and audience_rating <= 5),
  audience_rating_count integer not null default 0
    check (audience_rating_count >= 0),

  -- Existing compatibility fields used by the initial Flutter prototype.
  -- Keep them during the transition from mock data.
  rating numeric(3, 1) not null default 0
    check (rating >= 0 and rating <= 5),
  audience_votes integer not null default 0
    check (audience_votes >= 0),
  year text not null default '2026',

  -- Home, Browse, and Vote section flags
  is_featured boolean not null default false,
  is_trending boolean not null default false,
  in_library boolean not null default true,
  in_vote_ballot boolean not null default false,

  -- External-media-ready fields.
  -- The application may use:
  --   - Bunny.net URLs for trailers or playback
  --   - Google Drive temporarily for internal/review workflows
  --   - Flutter local assets as a fallback
  --
  -- Do not upload or migrate files to Supabase Storage in this phase.
  poster_url text,
  hero_image_url text,
  trailer_url text,
  video_url text,

  media_provider text not null default 'local'
    check (media_provider in ('local', 'bunny', 'google_drive', 'external')),

  media_status text not null default 'placeholder'
    check (media_status in ('placeholder', 'temporary', 'approved', 'archived')),

  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);


-- Backward-compatible column additions if a partial earlier schema was applied.
alter table public.films
  add column if not exists slug text,
  add column if not exists release_year integer,
  add column if not exists audience_rating numeric(3, 2),
  add column if not exists audience_rating_count integer,
  add column if not exists poster_url text,
  add column if not exists hero_image_url text,
  add column if not exists trailer_url text,
  add column if not exists video_url text,
  add column if not exists media_provider text,
  add column if not exists media_status text,
  add column if not exists updated_at timestamptz;


-- Use safe defaults for installations where these columns were added later.
update public.films
set
  release_year = coalesce(release_year, 2026),
  audience_rating = coalesce(audience_rating, rating, 0),
  audience_rating_count = coalesce(audience_rating_count, audience_votes, 0),
  media_provider = coalesce(media_provider, 'local'),
  media_status = coalesce(media_status, 'placeholder'),
  updated_at = coalesce(updated_at, created_at, now())
where
  release_year is null
  or audience_rating is null
  or audience_rating_count is null
  or media_provider is null
  or media_status is null
  or updated_at is null;


-- Ensure RLS is enabled.
alter table public.films enable row level security;


-- Explicit access grants:
-- both unauthenticated visitors and authenticated users may read the public
-- catalogue. No client-side write grants are given.
grant select on table public.films to anon, authenticated;


-- Public catalogue read policy.
drop policy if exists "Films are publicly readable" on public.films;
drop policy if exists "Public films are readable" on public.films;

create policy "Public films are readable"
  on public.films
  for select
  to anon, authenticated
  using (true);


-- Indexes for Home, Browse, search filtering, and media lookups.
create unique index if not exists films_slug_unique_idx
  on public.films (slug)
  where slug is not null;

create index if not exists films_category_idx
  on public.films (category);

create index if not exists films_country_idx
  on public.films (country);

create index if not exists films_release_year_idx
  on public.films (release_year);

create index if not exists films_featured_idx
  on public.films (is_featured)
  where is_featured = true;

create index if not exists films_trending_idx
  on public.films (is_trending)
  where is_trending = true;

create index if not exists films_library_idx
  on public.films (in_library)
  where in_library = true;

create index if not exists films_vote_ballot_idx
  on public.films (in_vote_ballot)
  where in_vote_ballot = true;

create index if not exists films_audience_rating_idx
  on public.films (audience_rating desc);

create index if not exists films_rating_idx
  on public.films (rating desc);


-- Automatic updated_at behavior.
drop trigger if exists films_set_updated_at on public.films;

create trigger films_set_updated_at
before update on public.films
for each row
execute function public.set_updated_at();


-- ============================================================================
-- votes
-- ============================================================================
--
-- This is currently a one-to-one audience-rating table:
--
--   one permanent authenticated user
--   + one film
--   = one 1–5 star rating
--
-- It is NOT yet a paid voting / vote-credit system.
--
-- Security:
--   - Local-only guests must not write to Supabase.
--   - Unauthenticated visitors have no write grant.
--   - Permanent authenticated users can only read, insert, and update their
--     own rows.
--   - Supabase anonymous users are denied by the restrictive JWT policy.
-- ============================================================================

create table if not exists public.votes (
  id uuid primary key default gen_random_uuid(),

  film_id uuid not null
    references public.films (id)
    on delete cascade,

  user_id uuid not null
    references auth.users (id)
    on delete cascade,

  rating smallint not null
    check (rating between 1 and 5),

  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),

  constraint votes_one_rating_per_user_per_film
    unique (film_id, user_id)
);


-- If an earlier development version used numeric ratings, preserve existing
-- values only when they are whole valid star ratings.
--
-- Do not force a column type conversion automatically here if this schema has
-- already been used with decimals. For a fresh project, the definition above
-- creates smallint correctly.
--
-- If you have already applied the old schema and have no real rating data yet,
-- run this manually after reviewing:
--
-- alter table public.votes
--   alter column rating type smallint using round(rating)::smallint;
--


alter table public.votes enable row level security;


-- Only authenticated users receive direct table privileges. RLS determines
-- which exact rows they may access.
grant select, insert, update on table public.votes to authenticated;


-- Helpful indexes for RLS and direct lookups.
create index if not exists votes_user_id_idx
  on public.votes (user_id);

create index if not exists votes_film_id_idx
  on public.votes (film_id);


-- Remove previous development policy names safely.
drop policy if exists "Users can read their own votes" on public.votes;
drop policy if exists "Users can insert their own votes" on public.votes;
drop policy if exists "Users can update their own votes" on public.votes;
drop policy if exists "Owners can access their own votes" on public.votes;
drop policy if exists "Permanent users own their vote rows" on public.votes;
drop policy if exists "Must not be anonymous" on public.votes;
drop policy if exists "Only permanent users may manage votes" on public.votes;
drop policy if exists "Anonymous users cannot manage votes" on public.votes;


-- Permissive policy:
-- establishes that an authenticated user may access only rows they own.
create policy "Permanent users own their vote rows"
  on public.votes
  as permissive
  for all
  to authenticated
  using (
    (select auth.uid()) is not null
    and (select auth.uid()) = user_id
  )
  with check (
    (select auth.uid()) is not null
    and (select auth.uid()) = user_id
  );


-- Restrictive policy:
-- additionally rejects Supabase anonymous-auth users.
--
-- Note:
-- Your Flutter app must still not call signInAnonymously(). This policy is
-- defense in depth if an anonymous session is introduced accidentally later.
create policy "Only permanent users may manage votes"
  on public.votes
  as restrictive
  for all
  to authenticated
  using (
    coalesce(
      ((select auth.jwt()) ->> 'is_anonymous')::boolean,
      false
    ) = false
  )
  with check (
    coalesce(
      ((select auth.jwt()) ->> 'is_anonymous')::boolean,
      false
    ) = false
  );


-- Automatic updated_at behavior.
drop trigger if exists votes_set_updated_at on public.votes;

create trigger votes_set_updated_at
before update on public.votes
for each row
execute function public.set_updated_at();


-- ============================================================================
-- vote_bundles
-- ============================================================================
--
-- Catalogue of purchasable vote bundles, priced here and referenced by the
-- `payments` table (see below) when a user buys one via Ziina.
--
-- This table does NOT grant vote credits by itself; the `payments` table
-- records the purchase outcome and `payments.votes_granted` reflects what
-- was actually credited once Ziina confirms the payment.
-- ============================================================================

create table if not exists public.vote_bundles (
  id text primary key,

  votes integer not null
    check (votes > 0),

  label text not null,
  description text not null,

  price numeric(10, 2) not null
    check (price >= 0),

  currency text not null default 'AED'
    check (char_length(currency) = 3),

  is_best_value boolean not null default false,
  sort_order integer not null default 0,

  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);


-- Backward-compatible columns for a previous partial schema.
alter table public.vote_bundles
  add column if not exists currency text,
  add column if not exists created_at timestamptz,
  add column if not exists updated_at timestamptz;

update public.vote_bundles
set
  currency = coalesce(currency, 'AED'),
  created_at = coalesce(created_at, now()),
  updated_at = coalesce(updated_at, created_at, now())
where
  currency is null
  or created_at is null
  or updated_at is null;

alter table public.vote_bundles
  alter column currency set default 'AED';


alter table public.vote_bundles enable row level security;


-- Public display access only.
grant select on table public.vote_bundles to anon, authenticated;


drop policy if exists "Vote bundles are publicly readable" on public.vote_bundles;
drop policy if exists "Public vote bundles are readable" on public.vote_bundles;

create policy "Public vote bundles are readable"
  on public.vote_bundles
  for select
  to anon, authenticated
  using (true);


create index if not exists vote_bundles_sort_order_idx
  on public.vote_bundles (sort_order);


drop trigger if exists vote_bundles_set_updated_at on public.vote_bundles;

create trigger vote_bundles_set_updated_at
before update on public.vote_bundles
for each row
execute function public.set_updated_at();


-- ============================================================================
-- Seed: vote bundle display catalogue
-- ============================================================================
--
-- These prices are authoritative for Ziina payment intents.
-- ============================================================================

insert into public.vote_bundles (
  id,
  votes,
  label,
  description,
  price,
  currency,
  is_best_value,
  sort_order
)
values
  (
    'single',
    1,
    '1 vote',
    'Perfect for one favorite film',
    5.00,
    'AED',
    false,
    1
  ),
  (
    'five',
    5,
    '5 votes',
    'Vote across multiple categories',
    25.00,
    'AED',
    true,
    2
  ),
  (
    'ten',
    10,
    '10 votes',
    'For dedicated festival supporters',
    50.00,
    'AED',
    false,
    3
  )
on conflict (id) do update
set
  votes = excluded.votes,
  label = excluded.label,
  description = excluded.description,
  price = excluded.price,
  currency = excluded.currency,
  is_best_value = excluded.is_best_value,
  sort_order = excluded.sort_order,
  updated_at = now();


-- ============================================================================
-- Seed: temporary catalogue films
-- ============================================================================
--
-- These records populate the Flutter UI immediately.
--
-- Replace poster_url, hero_image_url, trailer_url, and video_url later with
-- approved Bunny.net URLs, or other permitted HTTPS sources.
--
-- Keep Google Drive as an internal/review source until you have stable,
-- approved delivery URLs. Do not expose private Drive files in the app.
-- ============================================================================

insert into public.films (
  title,
  slug,
  category,
  director,
  country,
  country_flag,
  duration_minutes,
  release_year,
  year,
  badge,
  synopsis,
  tags,
  audience_rating,
  audience_rating_count,
  rating,
  audience_votes,
  is_featured,
  is_trending,
  in_library,
  in_vote_ballot,
  media_provider,
  media_status
)
values
  (
    'The Silent Hour',
    'the-silent-hour',
    'Drama',
    'Y. Amrani',
    'Morocco',
    '🇲🇦',
    112,
    2026,
    '2026',
    'Official Selection',
    '',
    array['Drama', 'Official Selection'],
    4.80,
    112,
    4.8,
    112,
    true,
    false,
    true,
    false,
    'local',
    'placeholder'
  ),
  (
    'Echoes of Tomorrow',
    'echoes-of-tomorrow',
    'Sci-Fi',
    'L. Fontaine',
    'France',
    '🇫🇷',
    128,
    2026,
    '2026',
    'Premiere',
    '',
    array['Sci-Fi', 'Premiere'],
    4.60,
    0,
    4.6,
    0,
    true,
    false,
    true,
    false,
    'local',
    'placeholder'
  ),
  (
    'Shadow Line',
    'shadow-line',
    'Noir',
    'K. Tanaka',
    'Japan',
    '🇯🇵',
    88,
    2026,
    '2026',
    '',
    '',
    array['Noir'],
    4.50,
    0,
    4.5,
    0,
    false,
    true,
    true,
    false,
    'local',
    'placeholder'
  ),
  (
    'Golden Dust',
    'golden-dust',
    'Drama',
    'H. Saleh',
    'Egypt',
    '🇪🇬',
    104,
    2026,
    '2026',
    '',
    '',
    array['Drama'],
    4.40,
    0,
    4.4,
    0,
    false,
    true,
    true,
    false,
    'local',
    'placeholder'
  ),
  (
    'Sands of Time',
    'sands-of-time',
    'Documentary',
    'N. Belkacem',
    'Morocco',
    '🇲🇦',
    76,
    2026,
    '2026',
    '',
    '',
    array['Documentary'],
    4.70,
    0,
    4.7,
    0,
    false,
    true,
    true,
    false,
    'local',
    'placeholder'
  ),
  (
    'Sabab',
    'sabab',
    'Drama',
    'Y. Amrani',
    'Morocco',
    '🇲🇦',
    96,
    2026,
    '2026',
    '',
    '',
    array['Drama'],
    4.80,
    0,
    4.8,
    0,
    false,
    false,
    true,
    false,
    'local',
    'placeholder'
  ),
  (
    'Dunes of Time',
    'dunes-of-time',
    'Documentary',
    'L. Fontaine',
    'France',
    '🇫🇷',
    82,
    2026,
    '2026',
    '',
    '',
    array['Documentary'],
    4.60,
    0,
    4.6,
    0,
    false,
    false,
    true,
    false,
    'local',
    'placeholder'
  ),
  (
    'Midnight Cairo',
    'midnight-cairo',
    'Thriller',
    'H. Saleh',
    'Egypt',
    '🇪🇬',
    101,
    2026,
    '2026',
    '',
    '',
    array['Thriller'],
    4.40,
    0,
    4.4,
    0,
    false,
    false,
    true,
    false,
    'local',
    'placeholder'
  ),
  (
    'Silent Peaks',
    'silent-peaks',
    'Documentary',
    'K. Tanaka',
    'Japan',
    '🇯🇵',
    94,
    2026,
    '2026',
    '',
    '',
    array['Documentary'],
    4.90,
    0,
    4.9,
    0,
    false,
    false,
    true,
    false,
    'local',
    'placeholder'
  ),
  (
    'Her Own Voice',
    'her-own-voice',
    'Drama',
    'N. Belkacem',
    'Morocco',
    '🇲🇦',
    89,
    2026,
    '2026',
    '',
    '',
    array['Drama'],
    4.70,
    0,
    4.7,
    0,
    false,
    false,
    true,
    false,
    'local',
    'placeholder'
  ),
  (
    'The Last Reel',
    'the-last-reel',
    'Short',
    'M. Costa',
    'France',
    '🇫🇷',
    22,
    2026,
    '2026',
    '',
    '',
    array['Short'],
    4.30,
    0,
    4.3,
    0,
    false,
    false,
    true,
    false,
    'local',
    'placeholder'
  ),
  (
    'Neural Dawn',
    'neural-dawn',
    'AI',
    '',
    '',
    '',
    14,
    2026,
    '2026',
    '',
    '',
    array['AI'],
    0,
    0,
    0,
    0,
    false,
    false,
    false,
    true,
    'local',
    'placeholder'
  ),
  (
    'Silent Room',
    'silent-room',
    'Short',
    '',
    '',
    '',
    8,
    2026,
    '2026',
    '',
    '',
    array['Short'],
    0,
    0,
    0,
    0,
    false,
    false,
    false,
    true,
    'local',
    'placeholder'
  ),
  (
    'Wild Horizon',
    'wild-horizon',
    'Documentary',
    '',
    '',
    '',
    42,
    2026,
    '2026',
    '',
    '',
    array['Documentary'],
    0,
    0,
    0,
    0,
    false,
    false,
    false,
    true,
    'local',
    'placeholder'
  ),
  (
    'Paper Skies',
    'paper-skies',
    'Animation',
    '',
    '',
    '',
    11,
    2026,
    '2026',
    '',
    '',
    array['Animation'],
    0,
    0,
    0,
    0,
    false,
    false,
    false,
    true,
    'local',
    'placeholder'
  ),
  (
    'Event Horizon',
    'event-horizon',
    'AI',
    '',
    '',
    '',
    19,
    2026,
    '2026',
    '',
    '',
    array['AI'],
    0,
    0,
    0,
    0,
    false,
    false,
    false,
    true,
    'local',
    'placeholder'
  ),
  (
    'Sands of Memory',
    'sands-of-memory',
    'Drama',
    'Karim Al-Rashid',
    'Morocco',
    '🇲🇦',
    118,
    2026,
    '2026',
    'Official Selection',
    'In a fading desert village, an aging cartographer returns home to map the shifting dunes that once buried his family''s history. As memories resurface with each grain of sand, he confronts the silence of a generation and the fragile line between remembrance and loss. A meditative portrait of exile, longing, and the landscapes that hold our stories.',
    array['Official Selection', 'Drama'],
    4.60,
    1284,
    4.6,
    1284,
    false,
    false,
    true,
    false,
    'local',
    'placeholder'
  )
on conflict (slug) do update
set
  title = excluded.title,
  category = excluded.category,
  director = excluded.director,
  country = excluded.country,
  country_flag = excluded.country_flag,
  duration_minutes = excluded.duration_minutes,
  release_year = excluded.release_year,
  year = excluded.year,
  badge = excluded.badge,
  synopsis = excluded.synopsis,
  tags = excluded.tags,
  audience_rating = excluded.audience_rating,
  audience_rating_count = excluded.audience_rating_count,
  rating = excluded.rating,
  audience_votes = excluded.audience_votes,
  is_featured = excluded.is_featured,
  is_trending = excluded.is_trending,
  in_library = excluded.in_library,
  in_vote_ballot = excluded.in_vote_ballot,
  media_provider = excluded.media_provider,
  media_status = excluded.media_status,
  updated_at = now();


-- ============================================================================
-- profiles
-- ============================================================================
--
-- One row per permanent authenticated user, keyed by `auth.users.id`.
-- Automatically created on signup via trigger so the app never has to
-- insert a profile row itself.
--
-- Security:
--   - Local-only guests and unauthenticated visitors have no access.
--   - Signed-in users may only read/update their own row.
--   - Anonymous-auth sessions are rejected by a restrictive policy, same
--     defense-in-depth pattern used for `public.votes`.
-- ============================================================================

create table if not exists public.profiles (
  id uuid primary key
    references auth.users (id)
    on delete cascade,

  display_name text not null default '',
  avatar_url text,

  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.profiles enable row level security;

grant select, update on table public.profiles to authenticated;

drop policy if exists "Users can access their own profile" on public.profiles;
drop policy if exists "Only permanent users may manage their profile" on public.profiles;

create policy "Users can access their own profile"
  on public.profiles
  as permissive
  for all
  to authenticated
  using (
    (select auth.uid()) is not null
    and (select auth.uid()) = id
  )
  with check (
    (select auth.uid()) is not null
    and (select auth.uid()) = id
  );

create policy "Only permanent users may manage their profile"
  on public.profiles
  as restrictive
  for all
  to authenticated
  using (
    coalesce(
      ((select auth.jwt()) ->> 'is_anonymous')::boolean,
      false
    ) = false
  )
  with check (
    coalesce(
      ((select auth.jwt()) ->> 'is_anonymous')::boolean,
      false
    ) = false
  );

drop trigger if exists profiles_set_updated_at on public.profiles;

create trigger profiles_set_updated_at
before update on public.profiles
for each row
execute function public.set_updated_at();


-- Auto-create a profile row whenever a new auth user is created. Runs as
-- the function owner (security definer) so it can write regardless of the
-- caller's RLS grants; `auth.users` inserts always originate server-side.
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (id, display_name)
  values (new.id, coalesce(new.raw_user_meta_data ->> 'display_name', ''))
  on conflict (id) do nothing;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;

create trigger on_auth_user_created
after insert on auth.users
for each row
execute function public.handle_new_user();


-- Backfill profiles for any existing authenticated users created before
-- this table/trigger existed.
insert into public.profiles (id, display_name)
select u.id, coalesce(u.raw_user_meta_data ->> 'display_name', '')
from auth.users u
where not coalesce((u.raw_app_meta_data ->> 'is_anonymous')::boolean, false)
on conflict (id) do nothing;


-- ============================================================================
-- payments
-- ============================================================================
--
-- Records vote-bundle purchases made through the Ziina payment gateway.
-- Rows are created (status = 'pending') by the `ziina-create-payment` edge
-- function and updated (status = 'completed' | 'failed' | 'canceled') by the
-- `ziina-webhook` edge function once Ziina confirms the outcome. Only the
-- service role (used by those edge functions) may insert/update rows;
-- clients get read-only access to their own rows via RLS.
-- ============================================================================

create table if not exists public.payments (
  id uuid primary key default gen_random_uuid(),

  user_id uuid not null
    references auth.users (id)
    on delete cascade,

  bundle_id text not null
    references public.vote_bundles (id),

  -- Client-generated UUID sent to Ziina; lets retries reuse the same intent.
  operation_id uuid not null default gen_random_uuid(),

  -- Ziina's own payment intent id, set once the intent is created.
  ziina_payment_intent_id text unique,

  amount numeric(10, 2) not null
    check (amount >= 0),
  currency text not null default 'AED'
    check (char_length(currency) = 3),

  status text not null default 'pending'
    check (status in ('pending', 'completed', 'failed', 'canceled')),

  -- Set once by the webhook when status first becomes 'completed'.
  votes_granted integer,

  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.payments enable row level security;

-- Clients may only read their own payment history. All writes happen
-- server-side (edge functions) using the service role, which bypasses RLS.
grant select on table public.payments to authenticated;

drop policy if exists "Users can read their own payments" on public.payments;

create policy "Users can read their own payments"
  on public.payments
  for select
  to authenticated
  using ((select auth.uid()) = user_id);

create index if not exists payments_user_id_idx
  on public.payments (user_id);

create index if not exists payments_ziina_payment_intent_id_idx
  on public.payments (ziina_payment_intent_id);

drop trigger if exists payments_set_updated_at on public.payments;

create trigger payments_set_updated_at
before update on public.payments
for each row
execute function public.set_updated_at();


-- ============================================================================
-- End of initial schema
-- ============================================================================
--
-- Next phases, intentionally not included in this file:
--
-- 1. announcements
-- 2. favorites and bookmarks
-- 3. film submissions
-- 4. Supabase Storage or approved external-media management
-- 5. automated public audience-rating aggregates
-- 6. separate film_ratings and festival_votes tables
-- 7. crediting purchased votes toward actual festival votes/ballots
-- 8. admin / jury roles and secure back-office workflows
-- ============================================================================