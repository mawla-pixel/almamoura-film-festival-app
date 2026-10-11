create table if not exists public.festival_submissions (
  id uuid primary key default gen_random_uuid(),
  source_submission_id text not null unique,
  project_title text not null,
  submission_status text not null,
  judging_status text,
  submission_date text,
  submission_deadlines text,
  submission_categories text not null,
  project_data jsonb not null default '{}'::jsonb,
  imported_at timestamptz not null default now(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint festival_submissions_project_data_object
    check (jsonb_typeof(project_data) = 'object')
);

create index if not exists festival_submissions_project_title_idx
  on public.festival_submissions (project_title);
create index if not exists festival_submissions_status_idx
  on public.festival_submissions (submission_status);
create index if not exists festival_submissions_categories_idx
  on public.festival_submissions
  using gin (to_tsvector('simple', submission_categories));
create index if not exists festival_submissions_project_data_idx
  on public.festival_submissions
  using gin (project_data jsonb_path_ops);

alter table public.festival_submissions enable row level security;
revoke all on table public.festival_submissions from anon, authenticated;
grant select on table public.festival_submissions to authenticated;

drop policy if exists "Festival admins can read submissions"
  on public.festival_submissions;
create policy "Festival admins can read submissions"
  on public.festival_submissions
  for select
  to authenticated
  using ((auth.jwt() -> 'app_metadata' ->> 'role') = 'festival_admin');

create or replace function public.set_festival_submissions_updated_at()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists festival_submissions_set_updated_at
  on public.festival_submissions;
create trigger festival_submissions_set_updated_at
before update on public.festival_submissions
for each row execute function public.set_festival_submissions_updated_at();
