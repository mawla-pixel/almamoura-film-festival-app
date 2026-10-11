alter table public.festival_poster_tracking
  drop column file_extension,
  add column object_path text not null
    check (
      object_path ~ (
        '^almamoura posters/' || tracking_number
        || '[[:space:]]*\.(jpg|jpeg|png|webp)$'
      )
    );

create or replace function public.sync_festival_poster_catalogue()
returns trigger
language plpgsql
security definer
set search_path = public, storage
as $$
declare
  submission_id text;
  tracking_number text;
  object_path text;
  film_id uuid;
  poster_url_value text;
begin
  if tg_op = 'DELETE' then
    submission_id := old.source_submission_id;
  else
    submission_id := new.source_submission_id;
    tracking_number := new.tracking_number;
    object_path := new.object_path;
  end if;

  select id
  into film_id
  from public.festival_submissions
  where source_submission_id = submission_id;

  if film_id is null then
    if tg_op = 'DELETE' then
      return old;
    end if;
    raise exception 'No festival submission found for poster mapping';
  end if;

  if tg_op = 'UPDATE'
    and old.source_submission_id is distinct from new.source_submission_id then
    update public.public_voting_films
    set poster_url = null, updated_at = now()
    where id = (
      select id
      from public.festival_submissions
      where source_submission_id = old.source_submission_id
    );
  end if;

  if tg_op = 'DELETE' then
    update public.public_voting_films
    set poster_url = null, updated_at = now()
    where id = film_id;
    return old;
  end if;

  if not exists (
    select 1
    from storage.objects
    where bucket_id = 'posters'
      and name = object_path
  ) then
    raise exception 'Poster object is missing from the posters bucket';
  end if;

  poster_url_value := 'https://cbksbxmzeqefbdqzbprn.supabase.co'
    || '/storage/v1/object/public/posters/'
    || replace(object_path, ' ', '%20');

  update public.public_voting_films
  set poster_url = poster_url_value, updated_at = now()
  where id = film_id;

  return new;
end;
$$;
