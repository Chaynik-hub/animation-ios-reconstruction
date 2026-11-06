begin;
create table if not exists public.community_projects (
  id uuid primary key,
  owner_id uuid not null references auth.users(id) on delete cascade,
  title text not null check (length(trim(title)) between 1 and 80),
  author text not null check (length(trim(author)) between 1 and 32),
  archive_path text not null unique,
  created_at timestamptz not null default now(),
  check (archive_path = owner_id::text || '/' || id::text || '.animationproject')
);
create table if not exists public.community_ratings (
  project_id uuid not null references public.community_projects(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  stars integer not null check (stars between 1 and 5),
  primary key (project_id,user_id)
);
create table if not exists public.community_comments (
  id uuid primary key default gen_random_uuid(),
  project_id uuid not null references public.community_projects(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  author text not null check (length(trim(author)) between 1 and 32),
  body text not null check (length(trim(body)) between 1 and 500),
  created_at timestamptz not null default now()
);
create index if not exists community_projects_created on public.community_projects(created_at desc,id desc);
create index if not exists community_projects_owner on public.community_projects(owner_id,created_at);
create index if not exists community_comments_project on public.community_comments(project_id,created_at desc);
create index if not exists community_comments_user on public.community_comments(user_id,created_at);
alter table public.community_projects enable row level security;
alter table public.community_ratings enable row level security;
alter table public.community_comments enable row level security;
create policy "Read published projects" on public.community_projects for select to authenticated using (true);
create policy "Publish own projects" on public.community_projects for insert to authenticated with check (
  owner_id = (select auth.uid()) and exists (
    select 1 from storage.objects where bucket_id = 'animation-projects' and name = archive_path
  )
);
create policy "Read ratings" on public.community_ratings for select to authenticated using (true);
create policy "Rate as self" on public.community_ratings for insert to authenticated with check (user_id = (select auth.uid()));
create policy "Change own rating" on public.community_ratings for update to authenticated using (user_id = (select auth.uid())) with check (user_id = (select auth.uid()));
create policy "Read comments" on public.community_comments for select to authenticated using (true);
create policy "Comment as self" on public.community_comments for insert to authenticated with check (user_id = (select auth.uid()));
revoke all on public.community_projects, public.community_ratings, public.community_comments from anon, authenticated;
grant select, insert on public.community_projects, public.community_comments to authenticated;
grant select, insert, update on public.community_ratings to authenticated;
create or replace view public.community_feed with (security_invoker = true) as
select p.id,p.title,p.author,p.archive_path,p.created_at,
       avg(r.stars)::double precision as average,count(r.user_id)::integer as votes
from public.community_projects p left join public.community_ratings r on r.project_id=p.id
group by p.id;
grant select on public.community_feed to authenticated;

-- A private bucket: read only published projects or the user's own pending upload.
insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types)
values ('animation-projects','animation-projects',false,52428800,array['application/zip'])
on conflict(id) do nothing;
create policy "Upload own archive" on storage.objects for insert to authenticated
with check (bucket_id='animation-projects' and (storage.foldername(name))[1]=(select auth.uid())::text
  and name ~ '^[0-9a-f-]{36}/[0-9a-f-]{36}\.animationproject$');
-- Do not query community_projects here: its INSERT policy checks storage.objects,
-- and a cross-table read policy would recurse. Published paths are distributed by
-- community_feed; authenticated clients can read archives, but cannot list anonymously.
create policy "Read community archives" on storage.objects for select to authenticated
using (bucket_id='animation-projects');
create policy "Remove own failed upload" on storage.objects for delete to authenticated
using (bucket_id='animation-projects' and (storage.foldername(name))[1]=(select auth.uid())::text
  and not exists (select 1 from public.community_projects where archive_path=name));

-- Serialize per-user publishing and prevent timestamp spoofing / routine spam.
create or replace function public.community_insert_guard() returns trigger
language plpgsql security definer set search_path = '' as $$
declare amount integer;
begin
  perform pg_advisory_xact_lock(hashtextextended(auth.uid()::text,0));
  if tg_table_name='community_projects' then
    select count(*) into amount from public.community_projects where owner_id=auth.uid() and created_at>now()-interval '1 day';
    if amount>=10 then raise exception 'Не более 10 публикаций в сутки'; end if;
  else
    select count(*) into amount from public.community_comments where user_id=auth.uid() and created_at>now()-interval '1 day';
    if amount>=100 then raise exception 'Не более 100 комментариев в сутки'; end if;
  end if;
  new.created_at=now(); return new;
end $$;
revoke all on function public.community_insert_guard() from public,anon,authenticated;
create trigger community_project_limit before insert on public.community_projects for each row execute function public.community_insert_guard();
create trigger community_comment_limit before insert on public.community_comments for each row execute function public.community_insert_guard();
commit;
