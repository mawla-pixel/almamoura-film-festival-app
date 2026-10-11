insert into storage.buckets (id, name, public)
values ('posters', 'posters', true)
on conflict (id) do update set public = true;

create table public.festival_poster_tracking (
  source_submission_id text primary key
    references public.festival_submissions(source_submission_id)
    on delete cascade,
  tracking_number text not null unique
    check (tracking_number ~ '^[0-9]+$'),
  file_extension text not null
    check (file_extension in ('jpg', 'jpeg', 'png', 'webp')),
  created_at timestamptz not null default now()
);

alter table public.festival_poster_tracking enable row level security;
revoke all on table public.festival_poster_tracking from anon, authenticated;
grant select, insert, update, delete
  on table public.festival_poster_tracking to authenticated;

create policy "Festival admins can manage poster tracking"
  on public.festival_poster_tracking
  for all
  to authenticated
  using ((auth.jwt() -> 'app_metadata' ->> 'role') = 'festival_admin')
  with check ((auth.jwt() -> 'app_metadata' ->> 'role') = 'festival_admin');

create or replace function public.sync_festival_poster_catalogue()
returns trigger
language plpgsql
security definer
set search_path = public, storage
as $$
declare
  submission_id text;
  tracking_number text;
  file_extension text;
  film_id uuid;
  object_path text;
  poster_url_value text;
begin
  if tg_op = 'DELETE' then
    submission_id := old.source_submission_id;
  else
    submission_id := new.source_submission_id;
    tracking_number := new.tracking_number;
    file_extension := new.file_extension;
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

  object_path := 'almamoura posters/'
    || tracking_number || '.' || file_extension;

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

create trigger festival_poster_tracking_sync_catalogue
  after insert or update or delete
  on public.festival_poster_tracking
  for each row execute function public.sync_festival_poster_catalogue();
