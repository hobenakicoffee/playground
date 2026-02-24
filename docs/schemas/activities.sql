/*
  migration: create_activities_table
  purpose:
    - unified activity feed derived from transactions
    - supports creator feed + supporter feed
    - works with user-centric transaction ledger
    - stores display metadata only (no money logic)
  notes:
    - activity links to a single transaction row
    - reference_id groups multiple transactions logically
    - activities are immutable once created
*/

-- ---------------------------------------------------------
-- activities
-- ---------------------------------------------------------

create table public.activities (
  id uuid primary key default gen_random_uuid(),

  -- source transaction (single ledger row)
  -- Can be null for activities like follows that don't have a transaction
  transaction_id uuid
    references public.transactions(id)
    on delete cascade,

  -- shared logical reference (same as transactions.reference_id)
  reference_id uuid not null,

  -- activity owner (who sees this in their feed)
  user_profile_id uuid
    not null
    references public.profiles(id)
    on delete cascade,

  -- counterparty (optional, for display)
  counterparty_profile_id uuid
    references public.profiles(id)
    on delete set null,

  -- role in this activity (viewer perspective)
  role varchar(20) not null
    check (role in ('creator', 'supporter', 'system')),

  -- service type for filtering (mirrors transactions.service_type)
  service_type varchar(20) not null default 'gift',

  -- activity display metadata (message, coffee_count, etc.)
  metadata jsonb not null default '{}'::jsonb,

  -- visibility control (public creator feed vs private)
  visibility public.visibility_enum not null default 'public',

  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

comment on table public.activities is
'Unified activity feed derived from transactions, scoped per user.';

-- ---------------------------------------------------------
-- Row Level Security
-- ---------------------------------------------------------

alter table public.activities enable row level security;

-- ---------------------------------------------------------
-- SELECT POLICIES
-- ---------------------------------------------------------

-- Anonymous users can view public activities only
create policy "Anonymous users can view public activities"
on public.activities
for select
to anon
using (visibility = 'public');

-- Authenticated users can view:
-- 1. their own activities
-- 2. public activities
create policy "Users can view own or public activities"
on public.activities
for select
to authenticated
using (
  visibility = 'public'
  or user_profile_id = (select auth.uid())
);

-- ---------------------------------------------------------
-- INSERT POLICIES
-- ---------------------------------------------------------

-- Only backend / RPC should insert activities
create policy "Block direct inserts on activities"
on public.activities
for insert
to authenticated
with check (false);

-- ---------------------------------------------------------
-- UPDATE / DELETE POLICIES
-- ---------------------------------------------------------

-- Activities are immutable (except visibility via system)
create policy "Block updates on activities"
on public.activities
for update
to authenticated
using (false);

create policy "Block deletes on activities"
on public.activities
for delete
to authenticated
using (false);

-- ---------------------------------------------------------
-- INDEXES
-- ---------------------------------------------------------

create index idx_activities_user_profile_id
  on public.activities(user_profile_id);

create index idx_activities_counterparty_profile_id
  on public.activities(counterparty_profile_id);

create index idx_activities_transaction_id
  on public.activities(transaction_id);

create index idx_activities_reference_id
  on public.activities(reference_id);

create index idx_activities_visibility
  on public.activities(visibility);

create index idx_activities_created_at
  on public.activities(created_at desc);

-- composite index for filtered pagination queries
create index idx_activities_user_service_created
  on public.activities(user_profile_id, service_type, created_at desc);

-- ---------------------------------------------------------
-- TRIGGER: auto-update updated_at
-- ---------------------------------------------------------

create trigger on_activity_updated
before update on public.activities
for each row
execute procedure public.handle_updated_at();
