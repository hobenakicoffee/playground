/*
  migration: create_transactions_table
  purpose:
    - tracks all financial transactions (gifts, subscriptions, payouts)
    - maintains transaction history with provider details
    - records balance snapshots after each transaction
    - supports both debit and credit operations
    - user-centric ledger model, transactions belongs to user profiles
  notes:
    - supporter_id is nullable for payout transactions
    - reference_id links to coffee_gifts or other source tables
    - balance_after provides point-in-time balance snapshot
    - metadata stores provider-specific transaction details
*/

-- ---------------------------------------------------------
-- transactions
-- ---------------------------------------------------------

create table public.transactions (
  id uuid primary key default gen_random_uuid(),

  -- OWNER of this transaction (who sees it in their ledger)
  user_profile_id uuid not null references public.profiles(id) on delete cascade,

  -- Optional counterparty (another user involved)
  counterparty_profile_id uuid references public.profiles(id) on delete set null,

  -- Optional supporter entity (analytics / attribution)
  supporter_id uuid references public.supporters(id) on delete set null,

  -- Optional creator context (who received the support)
  creator_profile_id uuid references public.profiles(id) on delete set null,

  -- classification
  service_type varchar(20) not null default 'gift',
  reference_type public.reference_type_enum not null,
  direction public.transaction_direction_enum not null,

  -- financials (ALWAYS positive numbers)
  amount numeric(10,2) not null check (amount >= 0),
  platform_fee numeric(10,2) not null default 0 check (platform_fee >= 0),
  net_amount numeric(10,2) not null check (net_amount >= 0),

  constraint transactions_amount_consistency check (amount = platform_fee + net_amount),

  -- payment lifecycle
  status public.payment_status_enum not null,

  -- provider info
  provider public.provider_enum,
  provider_transaction_id varchar,

  -- business reference
  reference_id uuid unique,

  -- wallet snapshot for THIS user
  balance_after bigint not null check (balance_after >= 0),

  -- wallet reference (NULL = platform/payment-side transaction, NOT NULL = wallet ledger transaction)
  wallet_id uuid references public.wallets(id) on delete set null,

  -- extensible metadata
  metadata jsonb not null default '{}'::jsonb,

  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

comment on table public.transactions is
'User-centric financial ledger. Each row represents a transaction from one user’s perspective.';

alter table public.transactions enable row level security;

create policy "Users can view their own transactions"
on public.transactions
for select
to authenticated
using (
  user_profile_id = (select auth.uid())
);

create index idx_transactions_user_profile_id
on public.transactions(user_profile_id);

create index idx_transactions_counterparty_profile_id
on public.transactions(counterparty_profile_id);

create index idx_transactions_creator_profile_id
on public.transactions(creator_profile_id);

create index idx_transactions_supporter_id
on public.transactions(supporter_id);

create index idx_transactions_reference_id
on public.transactions(reference_id);

create index idx_transactions_created_at
on public.transactions(created_at desc);

create index idx_transactions_status
on public.transactions(status);

create index idx_transactions_provider_tx
on public.transactions(provider, provider_transaction_id);

create index idx_transactions_service_type
on public.transactions(service_type);

create index idx_transactions_direction
on public.transactions(direction);

create index idx_transactions_reference_type
on public.transactions(reference_type);

create index idx_transactions_provider
on public.transactions(provider);

create index idx_transactions_wallet_id
on public.transactions(wallet_id);

-- ---------------------------------------------------------
-- trigger for auto-updating updated_at
-- ---------------------------------------------------------

create trigger on_transaction_updated
  before update on public.transactions
  for each row
  execute procedure public.handle_updated_at();
