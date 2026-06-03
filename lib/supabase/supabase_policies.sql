-- Faithful Journal (Supabase) — Row Level Security policies

-- USERS
alter table public.users enable row level security;

drop policy if exists "Users can read own profile" on public.users;
create policy "Users can read own profile"
on public.users
for select
to authenticated
using (auth.uid() = id);

-- IMPORTANT: allow profile creation/updates during signup/onboarding flows.
-- Per Dreamflow guidelines: WITH CHECK (true) for INSERT/UPDATE on users.
drop policy if exists "Users can insert profile" on public.users;
create policy "Users can insert profile"
on public.users
for insert
to authenticated
with check (true);

drop policy if exists "Users can update profile" on public.users;
create policy "Users can update profile"
on public.users
for update
to authenticated
using (auth.uid() = id)
with check (true);

drop policy if exists "Users can delete own profile" on public.users;
create policy "Users can delete own profile"
on public.users
for delete
to authenticated
using (auth.uid() = id);

-- JOURNAL ENTRIES
alter table public.journal_entries enable row level security;

drop policy if exists "Journal entries: user can select own" on public.journal_entries;
create policy "Journal entries: user can select own"
on public.journal_entries
for select
to authenticated
using (auth.uid() = user_id);

drop policy if exists "Journal entries: user can insert own" on public.journal_entries;
create policy "Journal entries: user can insert own"
on public.journal_entries
for insert
to authenticated
with check (auth.uid() = user_id);

drop policy if exists "Journal entries: user can update own" on public.journal_entries;
create policy "Journal entries: user can update own"
on public.journal_entries
for update
to authenticated
using (auth.uid() = user_id)
with check (auth.uid() = user_id);

drop policy if exists "Journal entries: user can delete own" on public.journal_entries;
create policy "Journal entries: user can delete own"
on public.journal_entries
for delete
to authenticated
using (auth.uid() = user_id);
