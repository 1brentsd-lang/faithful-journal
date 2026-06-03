-- Faithful Journal (Supabase) — Schema
--
-- This file is intended to be safe to apply to a fresh project OR an existing one.
-- It uses IF NOT EXISTS / ADD COLUMN IF NOT EXISTS where practical.

-- Required for gen_random_uuid()
create extension if not exists pgcrypto;

-- Public profile table (references auth.users)
create table if not exists public.users (
  id uuid primary key references auth.users(id) on delete cascade,
  name text not null default '',
  email text not null default '',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- Journal entries
create table if not exists public.journal_entries (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  scripture_reference text not null,
  scripture_text text,
  observation text not null,
  observation_structured jsonb,
  application text not null,
  prayer text not null,
  topic text not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- If your database already existed before these fields were added to the app,
-- ensure the columns exist.
alter table if exists public.journal_entries add column if not exists scripture_text text;
alter table if exists public.journal_entries add column if not exists observation_structured jsonb;

-- Helpful indexes
create index if not exists idx_journal_entries_user_id on public.journal_entries(user_id);
create index if not exists idx_journal_entries_created_at on public.journal_entries(created_at desc);
create index if not exists idx_journal_entries_topic on public.journal_entries(topic);
