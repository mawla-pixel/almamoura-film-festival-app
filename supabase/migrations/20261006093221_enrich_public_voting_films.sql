create or replace view public.public_voting_films with (security_barrier = true) as
select
  s.id,
  s.project_title as title,
  array[s.submission_categories]::text[] as project_types,
  coalesce(s.project_data ->> 'directors', '') as director,
  case
    when nullif(s.project_data ->> 'country_of_origin', '') is null
      then array[]::text[]
    else array[s.project_data ->> 'country_of_origin']
  end as countries_of_origin,
  0::numeric as rating,
  coalesce(
    nullif(substring(s.project_data ->> 'duration' from '^\s*([0-9]{1,4})'), '')::integer,
    0
  ) as duration_minutes,
  coalesce(
    substring(s.project_data ->> 'completion_date' from '([0-9]{4})$'),
    '2026'
  ) as year,
  coalesce(s.project_data ->> 'synopsis', '') as synopsis,
  coalesce(s.project_data ->> 'genres', '') as tags,
  s.project_data ->> 'trailer_url' as trailer_url,
  coalesce(sum(p.votes), 0)::bigint as audience_votes,
  s.project_data ->> 'original_title' as original_title,
  s.project_data ->> 'synopsis_original_language' as original_synopsis,
  s.project_data ->> 'completion_date' as completion_date,
  case
    when nullif(s.project_data ->> 'language', '') is null then array[]::text[]
    else regexp_split_to_array(s.project_data ->> 'language', '\s*[,;]\s*')
  end as languages,
  case
    when nullif(s.project_data ->> 'country_of_filming', '') is null then array[]::text[]
    else regexp_split_to_array(s.project_data ->> 'country_of_filming', '\s*[,;]\s*')
  end as countries_of_filming,
  s.project_data ->> 'aspect_ratio' as aspect_ratio,
  s.project_data ->> 'shooting_format' as shooting_format,
  s.project_data ->> 'film_color' as film_color,
  coalesce((s.project_data ->> 'student_project')::boolean, false)
    as is_student_project,
  false as is_ai_assisted,
  s.project_data ->> 'project_website' as official_website_url,
  null::text as badge,
  null::text as poster_url,
  null::text as hero_image_url,
  null::text as video_url,
  'external'::text as media_provider,
  'placeholder'::text as media_status,
  'published'::text as publication_status,
  'public'::text as visibility
from public.festival_submissions s
left join public.film_vote_payments p
  on p.film_id = s.id and p.status = 'completed'
group by s.id, s.project_title, s.submission_categories, s.project_data;
