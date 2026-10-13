-- Run this ONCE in Supabase: SQL Editor -> New query -> paste -> Run
create table if not exists public.records (
  tbl        text        not null,
  id         text        not null,
  data       jsonb       not null,
  updated_at timestamptz not null default now(),
  primary key (tbl, id)
);

alter table public.records enable row level security;

-- Demo policy: the app (anon key) may read/write. Tighten before real hospital use.
drop policy if exists "demo_all" on public.records;
create policy "demo_all" on public.records for all to anon using (true) with check (true);
