-- Faithful Journal (Supabase) — Incremental migration
-- Timestamp: 2026-07-08 15:37:05
--
-- Goal: bring the deployed database schema in sync with the current Flutter
-- client expectations (JournalEntry model + EntryService queries).

-- Journal entry enrichment fields (Questions, highlighting, legacy context)
alter table if exists public.journal_entries
  add column if not exists before_passage text;

alter table if exists public.journal_entries
  add column if not exists after_passage text;

alter table if exists public.journal_entries
  add column if not exists entry_type text not null default 'soap';

alter table if exists public.journal_entries
  add column if not exists highlighted boolean not null default false;

alter table if exists public.journal_entries
  add column if not exists question text;

alter table if exists public.journal_entries
  add column if not exists resolution text;

-- Parsed scripture metadata fields (used for grouping + search)
alter table if exists public.journal_entries
  add column if not exists book text;

alter table if exists public.journal_entries
  add column if not exists chapter integer;

alter table if exists public.journal_entries
  add column if not exists verse_start integer;

alter table if exists public.journal_entries
  add column if not exists verse_end integer;

alter table if exists public.journal_entries
  add column if not exists translation text;

-- Legacy column used by older imports/clients (kept optional)
alter table if exists public.journal_entries
  add column if not exists repeated_theme text;

-- Helpful indexes for metadata-driven queries
create index if not exists idx_journal_entries_book on public.journal_entries(book);
create index if not exists idx_journal_entries_chapter on public.journal_entries(chapter);
