drop view public.public_voting_films;

create table public.public_voting_films (
  id uuid primary key references public.festival_submissions(id) on delete cascade,
  title text not null,
  project_types text[] not null default '{}',
  director text not null default '',
  countries_of_origin text[] not null default '{}',
  rating numeric not null default 0,
  duration_minutes integer not null default 0,
  year text not null default '2026',
  synopsis text not null default '',
  tags text not null default '',
  trailer_url text,
  audience_votes bigint not null default 0 check (audience_votes >= 0),
  original_title text,
  original_synopsis text,
  completion_date text,
  languages text[] not null default '{}',
  countries_of_filming text[] not null default '{}',
  aspect_ratio text,
  shooting_format text,
  film_color text,
  is_student_project boolean not null default false,
  is_ai_assisted boolean not null default false,
  official_website_url text,
  badge text,
  poster_url text,
  hero_image_url text,
  video_url text,
  media_provider text not null default 'external',
  media_status text not null default 'placeholder',
  publication_status text not null default 'published',
  visibility text not null default 'public',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index public_voting_films_title_idx
  on public.public_voting_films (title);
create index public_voting_films_votes_idx
  on public.public_voting_films (audience_votes desc);

alter table public.public_voting_films enable row level security;
grant select on public.public_voting_films to anon, authenticated;
drop policy if exists "Public can read voting film catalogue"
  on public.public_voting_films;
create policy "Public can read voting film catalogue"
  on public.public_voting_films
  for select to anon, authenticated using (true);

create or replace function public.sync_voting_film_catalogue()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  insert into public.public_voting_films (
    id, title, project_types, director, countries_of_origin, rating,
    duration_minutes, year, synopsis, tags, trailer_url, original_title,
    original_synopsis, completion_date, languages, countries_of_filming,
    aspect_ratio, shooting_format, film_color, is_student_project,
    official_website_url
  ) values (
    new.id,
    new.project_title,
    array[new.submission_categories],
    coalesce(new.project_data ->> 'directors', ''),
    case
      when nullif(new.project_data ->> 'country_of_origin', '') is null
        then array[]::text[]
      else array[new.project_data ->> 'country_of_origin']
    end,
    0,
    coalesce(
      nullif(substring(new.project_data ->> 'duration'
        from '^\s*([0-9]{1,4})'), '')::integer,
      0
    ),
    coalesce(
      substring(new.project_data ->> 'completion_date'
        from '([0-9]{4})$'),
      '2026'
    ),
    coalesce(new.project_data ->> 'synopsis', ''),
    coalesce(new.project_data ->> 'genres', ''),
    new.project_data ->> 'trailer_url',
    new.project_data ->> 'original_title',
    new.project_data ->> 'synopsis_original_language',
    new.project_data ->> 'completion_date',
    case
      when nullif(new.project_data ->> 'language', '') is null
        then array[]::text[]
      else regexp_split_to_array(
        new.project_data ->> 'language', '\s*[,;]\s*'
      )
    end,
    case
      when nullif(new.project_data ->> 'country_of_filming', '') is null
        then array[]::text[]
      else regexp_split_to_array(
        new.project_data ->> 'country_of_filming', '\s*[,;]\s*'
      )
    end,
    new.project_data ->> 'aspect_ratio',
    new.project_data ->> 'shooting_format',
    new.project_data ->> 'film_color',
    coalesce((new.project_data ->> 'student_project')::boolean, false),
    new.project_data ->> 'project_website'
  )
  on conflict (id) do update set
    title = excluded.title,
    project_types = excluded.project_types,
    director = excluded.director,
    countries_of_origin = excluded.countries_of_origin,
    duration_minutes = excluded.duration_minutes,
    year = excluded.year,
    synopsis = excluded.synopsis,
    tags = excluded.tags,
    trailer_url = excluded.trailer_url,
    original_title = excluded.original_title,
    original_synopsis = excluded.original_synopsis,
    completion_date = excluded.completion_date,
    languages = excluded.languages,
    countries_of_filming = excluded.countries_of_filming,
    aspect_ratio = excluded.aspect_ratio,
    shooting_format = excluded.shooting_format,
    film_color = excluded.film_color,
    is_student_project = excluded.is_student_project,
    official_website_url = excluded.official_website_url,
    updated_at = now();
  return new;
end;
$$;

create trigger festival_submission_sync_voting_catalogue
  after insert or update of project_title, submission_categories, project_data
  on public.festival_submissions
  for each row execute function public.sync_voting_film_catalogue();

insert into public.public_voting_films (
  id, title, project_types, director, countries_of_origin, rating,
  duration_minutes, year, synopsis, tags, trailer_url, original_title,
  original_synopsis, completion_date, languages, countries_of_filming,
  aspect_ratio, shooting_format, film_color, is_student_project,
  official_website_url
)
select
  s.id,
  s.project_title,
  array[s.submission_categories],
  coalesce(s.project_data ->> 'directors', ''),
  case
    when nullif(s.project_data ->> 'country_of_origin', '') is null
      then array[]::text[]
    else array[s.project_data ->> 'country_of_origin']
  end,
  0,
  coalesce(
    nullif(substring(s.project_data ->> 'duration'
      from '^\s*([0-9]{1,4})'), '')::integer,
    0
  ),
  coalesce(
    substring(s.project_data ->> 'completion_date' from '([0-9]{4})$'),
    '2026'
  ),
  coalesce(s.project_data ->> 'synopsis', ''),
  coalesce(s.project_data ->> 'genres', ''),
  s.project_data ->> 'trailer_url',
  s.project_data ->> 'original_title',
  s.project_data ->> 'synopsis_original_language',
  s.project_data ->> 'completion_date',
  case
    when nullif(s.project_data ->> 'language', '') is null
      then array[]::text[]
    else regexp_split_to_array(s.project_data ->> 'language', '\s*[,;]\s*')
  end,
  case
    when nullif(s.project_data ->> 'country_of_filming', '') is null
      then array[]::text[]
    else regexp_split_to_array(
      s.project_data ->> 'country_of_filming', '\s*[,;]\s*'
    )
  end,
  s.project_data ->> 'aspect_ratio',
  s.project_data ->> 'shooting_format',
  s.project_data ->> 'film_color',
  coalesce((s.project_data ->> 'student_project')::boolean, false),
  s.project_data ->> 'project_website'
from public.festival_submissions s
on conflict (id) do nothing;

create or replace function public.add_completed_film_votes()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  if new.status = 'completed' and old.status is distinct from 'completed' then
    update public.public_voting_films
      set audience_votes = audience_votes + new.votes,
          updated_at = now()
      where id = new.film_id;
    if not found then
      raise exception 'Voting catalogue entry for film % was not found', new.film_id;
    end if;
  end if;
  return new;
end;
$$;

create trigger film_vote_payment_add_votes
  after update of status on public.film_vote_payments
  for each row execute function public.add_completed_film_votes();
