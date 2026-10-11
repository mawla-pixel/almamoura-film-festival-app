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
  coalesce(sum(p.votes), 0)::bigint as audience_votes
from public.festival_submissions s
left join public.film_vote_payments p
  on p.film_id = s.id and p.status = 'completed'
group by s.id, s.project_title, s.submission_categories, s.project_data;
