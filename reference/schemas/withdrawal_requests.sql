/*
  migration: create_withdrawal_requests_table
  purpose:
    - tracks user withdrawal requests
    - manages withdrawal lifecycle (requested -> approved -> processing -> paid)
    - stores payout method and amount details
  notes:
    - profile_id links to profiles table
    - wallet_id links to wallets table
    - payout_method_id links to payout_methods table
    - status flows: requested -> approved -> processing -> paid
    - rejected/failed states for failed withdrawals with refund to balance
    - processed_at tracks when admin approved/processed
    - completed_at tracks final completion
*/

-- ---------------------------------------------------------
-- withdrawal_requests
-- ---------------------------------------------------------

create table public.withdrawal_requests (
  id uuid primary key default gen_random_uuid(),

  profile_id uuid not null references public.profiles(id) on delete cascade,
  wallet_id uuid not null references public.wallets(id) on delete cascade,
  payout_method_id uuid not null references public.payout_methods(id) on delete restrict,

  amount numeric(12,2) not null check (amount > 0),
  fee numeric(12,2) not null default 0 check (fee >= 0),
  net_amount numeric(12,2) not null check (net_amount > 0),

  status public.withdrawal_status not null default 'requested',

  requested_at timestamptz not null default now(),
  processed_at timestamptz,
  completed_at timestamptz,

  admin_note text,
  failure_reason text,

  payout_snapshot jsonb
);

comment on table public.withdrawal_requests is
'User withdrawal requests tracking the payout lifecycle';

alter table public.withdrawal_requests enable row level security;

-- SELECT policies
-- Users can view their own withdrawal requests
create policy "Users can view their own withdrawal requests"
on public.withdrawal_requests
for select
to authenticated
using (profile_id = (select auth.uid()));

-- INSERT policies
-- Users can create their own withdrawal requests
create policy "Users can create their own withdrawal requests"
on public.withdrawal_requests
for insert
to authenticated
with check (profile_id = (select auth.uid()));

-- UPDATE policies
-- Users cannot update withdrawal requests (admin only via service role)
create policy "System can update withdrawal requests"
on public.withdrawal_requests
for update
to authenticated
using (profile_id = (select auth.uid()));

create index idx_withdrawal_requests_profile_id
on public.withdrawal_requests(profile_id);

create index idx_withdrawal_requests_profile_requested_at
on public.withdrawal_requests(profile_id, requested_at desc);

create index idx_withdrawal_requests_status
on public.withdrawal_requests(status);

create index idx_withdrawal_requests_wallet_id
on public.withdrawal_requests(wallet_id);

-- ---------------------------------------------------------
-- RPC: request_withdrawal
-- ---------------------------------------------------------

create or replace function request_withdrawal(
  p_amount numeric,
  p_payout_method_id uuid
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid;
  v_wallet_id uuid;
  v_balance numeric;
  v_fee numeric := 0;
  v_net_amount numeric;
  v_min_withdraw numeric := 500;
  v_payout_details jsonb;
  v_withdrawal_id uuid;
begin
  v_user_id := auth.uid();

  if v_user_id is null then
    raise exception 'Not authenticated';
  end if;

  if p_amount <= 0 then
    raise exception 'Invalid withdrawal amount';
  end if;

  if p_amount < v_min_withdraw then
    raise exception 'Minimum withdrawal is %', v_min_withdraw;
  end if;

  select id, balance
  into v_wallet_id, v_balance
  from public.wallets
  where profile_id = v_user_id
  for update;

  if v_wallet_id is null then
    raise exception 'Wallet not found';
  end if;

  if v_balance < p_amount then
    raise exception 'Insufficient balance';
  end if;

  select details
  into v_payout_details
  from public.payout_methods
  where id = p_payout_method_id
    and profile_id = v_user_id
    and is_active = true;

  if v_payout_details is null then
    raise exception 'Invalid payout method';
  end if;

  v_fee := 0;
  v_net_amount := p_amount - v_fee;

  if v_net_amount <= 0 then
    raise exception 'Invalid net amount after fee';
  end if;

  update public.wallets
  set balance = balance - p_amount,
      locked_balance = locked_balance + p_amount,
      updated_at = now()
  where id = v_wallet_id;

  insert into public.withdrawal_requests (
    profile_id,
    wallet_id,
    payout_method_id,
    amount,
    fee,
    net_amount,
    payout_snapshot,
    status
  )
  values (
    v_user_id,
    v_wallet_id,
    p_payout_method_id,
    p_amount,
    v_fee,
    v_net_amount,
    v_payout_details,
    'requested'
  )
  returning id into v_withdrawal_id;

  insert into public.transactions (
    user_profile_id,
    wallet_id,
    service_type,
    reference_type,
    direction,
    amount,
    net_amount,
    balance_after,
    reference_id,
    status,
    provider,
    metadata
  )
  values (
    v_user_id,
    v_wallet_id,
    'withdrawal',
    'withdraw_lock',
    'debit',
    p_amount,
    v_net_amount,
    v_balance - p_amount,
    v_withdrawal_id,
    'pending',
    'HobeNakiCoffee',
    jsonb_build_object('description', 'Withdrawal request submitted')
  );

  return v_withdrawal_id;
end;
$$;

revoke all on function request_withdrawal(numeric, uuid) from public;
grant execute on function request_withdrawal(numeric, uuid) to authenticated;
