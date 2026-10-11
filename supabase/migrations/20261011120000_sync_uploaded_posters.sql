alter table public.festival_poster_tracking
  alter column object_path drop not null,
  drop constraint if exists festival_poster_tracking_object_path_check,
  add constraint festival_poster_tracking_object_path_check
    check (
      object_path is null
      or object_path ~* (
        '^almamoura posters/' || tracking_number
        || '[[:space:]]*\.(jpg|jpeg|png|webp)$'
      )
    );

create unique index if not exists festival_poster_tracking_object_path_uidx
  on public.festival_poster_tracking (object_path)
  where object_path is not null;

create or replace function public.sync_festival_poster_catalogue()
returns trigger
language plpgsql
security definer
set search_path = public, storage
as $$
declare
  submission_id text;
  film_id uuid;
  poster_url_value text;
begin
  submission_id := case
    when tg_op = 'DELETE' then old.source_submission_id
    else new.source_submission_id
  end;

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

  if new.object_path is null then
    update public.public_voting_films
    set poster_url = null, updated_at = now()
    where id = film_id;
    return new;
  end if;

  if not exists (
    select 1
    from storage.objects
    where bucket_id = 'posters'
      and name = new.object_path
  ) then
    raise exception 'Poster object is missing from the posters bucket';
  end if;

  poster_url_value := 'https://cbksbxmzeqefbdqzbprn.supabase.co'
    || '/storage/v1/object/public/posters/'
    || replace(new.object_path, ' ', '%20');

  update public.public_voting_films
  set poster_url = poster_url_value, updated_at = now()
  where id = film_id;

  return new;
end;
$$;

create or replace function public.sync_uploaded_festival_poster()
returns trigger
language plpgsql
security definer
set search_path = public, storage
as $$
declare
  old_is_poster boolean := false;
  new_is_poster boolean := false;
  tracking_number_value text;
begin
  if tg_op <> 'INSERT' then
    old_is_poster := old.bucket_id = 'posters'
      and old.name like 'almamoura posters/%';
    if old_is_poster then
      update public.festival_poster_tracking
      set object_path = null
      where object_path = old.name;
    end if;
  end if;

  if tg_op <> 'DELETE' then
    new_is_poster := new.bucket_id = 'posters'
      and new.name ~* '^almamoura posters/[[:space:]]*[0-9]+[[:space:]]*\.(jpg|jpeg|png|webp)$';
    if new_is_poster then
      tracking_number_value := btrim(
        regexp_replace(
          split_part(new.name, '/', 2),
          '[[:space:]]*[.][^.]+$',
          ''
        )
      );
      update public.festival_poster_tracking
      set object_path = new.name
      where tracking_number = tracking_number_value;
    end if;
  end if;

  if tg_op = 'DELETE' then
    return old;
  end if;
  return new;
end;
$$;

drop trigger if exists storage_objects_sync_festival_poster
  on storage.objects;
create trigger storage_objects_sync_festival_poster
  after insert or update or delete
  on storage.objects
  for each row execute function public.sync_uploaded_festival_poster();

revoke execute on function public.sync_festival_poster_catalogue()
  from public, anon, authenticated, service_role;
revoke execute on function public.sync_uploaded_festival_poster()
  from public, anon, authenticated, service_role;
