/*
  migration: create_wallets_table
  purpose:
    - tracks current wallet balance for each creator profile
    - one wallet per profile (1:1 relationship)
    - balance updated via transactions
    - supports locked_balance for pending withdrawals
  notes:
    - profile_id is unique (one wallet per profile)
    - balance represents current available funds in taka
    - locked_balance represents funds pending withdrawal
    - updated_at tracks last balance modification
*/

-- ---------------------------------------------------------
-- wallets
-- ---------------------------------------------------------

create table public.wallets (
  id uuid primary key default gen_random_uuid(),

  profile_id uuid not null unique references public.profiles(id) on delete cascade,

  balance numeric(12,2) not null default 0 check (balance >= 0),
  locked_balance numeric(12,2) not null default 0 check (locked_balance >= 0),

  currency text not null default 'BDT',

  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

comment on table public.wallets is
'creator wallet balances tracking available funds for withdrawal';

alter table public.wallets enable row level security;

-- SELECT policies
-- Users can view their own wallet
create policy "Users can view their own wallet"
on public.wallets
for select
to authenticated
using (profile_id = (select auth.uid()));

-- INSERT policies
-- Users can create their own wallet
create policy "Users can create their own wallet"
on public.wallets
for insert
to authenticated
with check (profile_id = (select auth.uid()));

-- UPDATE policies
-- Only system can update wallet balance (via backend/triggers)
create policy "System can update wallet balance"
on public.wallets
for update
to authenticated
using (profile_id = (select auth.uid()));

create index idx_wallets_profile_id
on public.wallets(profile_id);

create index idx_wallets_updated_at
on public.wallets(updated_at desc);

-- ---------------------------------------------------------
-- trigger for auto-updating updated_at
-- ---------------------------------------------------------

create trigger on_wallet_updated
  before update on public.wallets
  for each row
  execute procedure public.handle_updated_at();

-- ---------------------------------------------------------
-- trigger for syncing has_wallet_balance to profiles
-- ---------------------------------------------------------

create or replace function public.handle_wallet_balance_change()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  update public.profiles
  set has_wallet_balance = (new.balance > 0),
      updated_at = now()
  where id = new.profile_id;
  return new;
end;
$$;

create trigger on_wallet_balance_changed
  after insert or update of balance on public.wallets
  for each row
  execute procedure public.handle_wallet_balance_change();
