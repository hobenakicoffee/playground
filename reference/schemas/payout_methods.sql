/*
  migration: create_payout_methods_table
  purpose:
    - stores user payout/withdrawal methods
    - supports mobile banking (bkash, nagad, rocket) and bank transfers
    - flexible JSONB storage for provider-specific details
  notes:
    - profile_id links to profiles table
    - is_default indicates primary payout method
    - is_active allows soft-deleting methods
    - details JSONB stores provider-specific data (account numbers, etc.)
*/

-- ---------------------------------------------------------
-- payout_methods
-- ---------------------------------------------------------

create table public.payout_methods (
  id uuid primary key default gen_random_uuid(),

  profile_id uuid not null references public.profiles(id) on delete cascade,

  provider public.payout_provider not null,

  details jsonb not null default '{}'::jsonb,
  /*
    examples:
    bkash: { "number": "01XXXXXXXXX", "type": "personal" }
    nagad: { "number": "01XXXXXXXXX", "type": "personal" }
    rocket: { "number": "01XXXXXXXXX", "type": "personal" }
    bank: {
      "bank_name": "BRAC Bank",
      "account_name": "John Doe",
      "account_number": "123456789",
      "routing_number": "090000",
      "branch_name": "Gulshan"
    }
  */

  is_default boolean not null default false,
  is_active boolean not null default true,

  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

comment on table public.payout_methods is
'User payout methods for withdrawal to mobile banking or bank accounts';

alter table public.payout_methods enable row level security;

-- SELECT policies
-- Users can view their own payout methods
create policy "Users can view their own payout methods"
on public.payout_methods
for select
to authenticated
using (profile_id = (select auth.uid()));

-- INSERT policies
-- Users can insert their own payout methods
create policy "Users can insert their own payout methods"
on public.payout_methods
for insert
to authenticated
with check (profile_id = (select auth.uid()));

-- UPDATE policies
-- Users can update their own payout methods
create policy "Users can update their own payout methods"
on public.payout_methods
for update
to authenticated
using (profile_id = (select auth.uid()));

-- DELETE policies
-- Users can delete their own payout methods
create policy "Users can delete their own payout methods"
on public.payout_methods
for delete
to authenticated
using (profile_id = (select auth.uid()));

create index idx_payout_methods_profile_id
on public.payout_methods(profile_id);

create index idx_payout_methods_profile_active
on public.payout_methods(profile_id, is_active);

-- ---------------------------------------------------------
-- trigger for auto-updating updated_at
-- ---------------------------------------------------------

create trigger on_payout_method_updated
  before update on public.payout_methods
  for each row
  execute procedure public.handle_updated_at();
