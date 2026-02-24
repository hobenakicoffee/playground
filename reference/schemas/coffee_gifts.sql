/*
  migration: create_coffee_gifts_table
  purpose:
    - stores completed coffee gifts only
    - supports anonymous & authenticated supporters
    - supports one-time and monthly gifts
    - links to unified transactions ledger via reference_id
  notes:
    - row is created ONLY after successful payment
    - no lifecycle or status column
    - transactions table is the source of truth for money
*/

-- ---------------------------------------------------------
-- coffee_gifts
-- ---------------------------------------------------------

create table public.coffee_gifts (
  id uuid primary key default gen_random_uuid(),

  -- creator receiving the coffee
  creator_profile_id uuid
    not null
    references public.profiles(id)
    on delete set null,

  -- authenticated supporter (nullable = anonymous)
  supporter_profile_id uuid
    references public.profiles(id)
    on delete set null,

  -- denormalized supporter snapshot (for anonymity + history)
  supporter_name varchar(100),
  supporter_platform varchar(30),

  -- gift message
  message varchar(500),

  -- business meaning only (pricing lives elsewhere)
  coffee_count integer not null
    check (coffee_count > 0),

  -- subscription type (future-ready)
  is_monthly boolean not null default false,

  -- shared reference to transactions ledger
  -- (multiple transaction rows share this reference_id)
  transaction_reference_id uuid
    not null
    references public.transactions(reference_id)
    on delete restrict,

  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

comment on table public.coffee_gifts is
'Completed coffee gifts only. Created after successful payment. Can be inserted by clients or system RPCs. Financial data lives in transactions table.';

-- ---------------------------------------------------------
-- Row Level Security
-- ---------------------------------------------------------

alter table public.coffee_gifts enable row level security;

-- ---------------------------------------------------------
-- SELECT POLICIES
-- ---------------------------------------------------------

-- Users can view all coffee gifts (public for everyone, plus own gifts for authenticated users)
create policy "Users can view coffee gifts"
on public.coffee_gifts
for select
to authenticated
using (
  true
  or supporter_profile_id = (select auth.uid())
  or creator_profile_id = (select auth.uid())
);

-- Anonymous users can view all coffee gifts
create policy "Anonymous can view coffee gifts"
on public.coffee_gifts
for select
to anon
using (true);

-- ---------------------------------------------------------
-- INSERT POLICIES
-- ---------------------------------------------------------

-- Users can insert coffee gifts after successful payment
-- Allow both authenticated and anonymous users
create policy "Users can insert coffee gifts"
on public.coffee_gifts
for insert
to authenticated, anon
with check (
  -- For authenticated users: check ownership
  ((select auth.role()) = 'authenticated' and (
    supporter_profile_id = (select auth.uid()) 
    or creator_profile_id = (select auth.uid())
  ))
  -- For anonymous users: allow only if supporter_profile_id is null
  or ((select auth.role()) = 'anon' and supporter_profile_id is null)
);

-- ---------------------------------------------------------
-- UPDATE / DELETE POLICIES
-- ---------------------------------------------------------

-- Coffee gifts are immutable
create policy "Block updates on coffee gifts"
on public.coffee_gifts
for update
to authenticated
using (false);

create policy "Block deletes on coffee gifts"
on public.coffee_gifts
for delete
to authenticated
using (false);

-- ---------------------------------------------------------
-- INDEXES
-- ---------------------------------------------------------

create index idx_coffee_gifts_creator_profile_id
  on public.coffee_gifts(creator_profile_id);

create index idx_coffee_gifts_supporter_profile_id
  on public.coffee_gifts(supporter_profile_id);

create index idx_coffee_gifts_transaction_reference_id
  on public.coffee_gifts(transaction_reference_id);

create index idx_coffee_gifts_created_at
  on public.coffee_gifts(created_at desc);

-- ---------------------------------------------------------
-- TRIGGER: auto-update updated_at
-- ---------------------------------------------------------

create trigger on_coffee_gifts_updated
before update on public.coffee_gifts
for each row
execute procedure public.handle_updated_at();
