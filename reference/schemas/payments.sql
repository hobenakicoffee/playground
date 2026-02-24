-- ---------------------------------------------------------
-- handle_successful_payment
-- ---------------------------------------------------------
create or replace function public.handle_successful_payment(
  p_creator_profile_id uuid,
  p_supporter_id uuid,
  p_amount numeric(10,2),
  p_platform_fee numeric(10,2),
  p_provider public.provider_enum,
  p_reference_type public.reference_type_enum,
  p_provider_transaction_id varchar,
  p_supporter_profile_id uuid default null,
  p_service_type varchar default 'gift',
  p_metadata jsonb default '{}'::jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  -- unique reference ids for each transaction
  v_supporter_reference_id uuid := gen_random_uuid();
  v_creator_reference_id uuid := gen_random_uuid();

  -- calculated values
  v_net_amount numeric(10,2);

  -- wallet balances
  v_supporter_balance numeric(12,2);
  v_creator_balance numeric(12,2);

  -- wallet ids
  v_supporter_wallet_id uuid;
  v_creator_wallet_id uuid;

  -- transaction ids
  v_supporter_tx_id uuid;
  v_creator_tx_id uuid;
begin
  -- ---------------------------------------------------
  -- 0. Security: Only allow service role (server-side) execution
  -- ---------------------------------------------------
  if auth.uid() is not null then
    raise exception 'Not allowed!';
  end if;

  -- ---------------------------------------------------
  -- 1. Input validation
  -- ---------------------------------------------------
  if p_amount <= 0 then
    raise exception 'Amount must be greater than zero';
  end if;

  if p_platform_fee < 0 then
    raise exception 'Platform fee cannot be negative';
  end if;

  if p_platform_fee > p_amount then
    raise exception 'Platform fee cannot exceed amount';
  end if;

  if p_provider = 'HobeNakiCoffee'
    and p_reference_type not in ('one-time', 'subscription') then
    raise exception 'HobeNakiCoffee payments must be one-time or subscription';
  end if;

  if p_supporter_profile_id is not null
    and p_creator_profile_id = p_supporter_profile_id then
    raise exception 'Cannot gift yourself';
  end if;

  -- ---------------------------------------------------
  -- 2. Calculate net amount
  -- ---------------------------------------------------
  v_net_amount := p_amount - p_platform_fee;

  -- ---------------------------------------------------
  -- 3. SUPPORTER SIDE (DEBIT)
  -- ---------------------------------------------------

  -- Handle anonymous supporters (no wallet operations)
  if p_supporter_profile_id is null then
    v_supporter_balance := null; -- Anonymous supporter, no wallet
  elsif p_provider = 'HobeNakiCoffee' then
    -- Ensure supporter wallet exists
    insert into public.wallets (profile_id, balance)
    values (p_supporter_profile_id, 0)
    on conflict (profile_id) do nothing;

    -- Lock supporter wallet
    select id, balance
    into v_supporter_wallet_id, v_supporter_balance
    from public.wallets
    where profile_id = p_supporter_profile_id
    for update;

    if v_supporter_balance < p_amount then
      raise exception 'Insufficient wallet balance';
    end if;

    -- Deduct supporter wallet
    update public.wallets
    set balance = balance - p_amount,
        updated_at = now()
    where profile_id = p_supporter_profile_id;

    v_supporter_balance := v_supporter_balance - p_amount;
  else
    -- External provider: no wallet deduction
    select balance
    into v_supporter_balance
    from public.wallets
    where profile_id = p_supporter_profile_id;

    -- Ensure balance_after is not null for transaction
    if v_supporter_balance is null then
      v_supporter_balance := 0;
    end if;
  end if;

  -- Insert supporter transaction (DEBIT) - only for authenticated supporters
  if p_supporter_profile_id is not null then
    insert into public.transactions (
      user_profile_id,
      counterparty_profile_id,
      supporter_id,
      creator_profile_id,
      direction,
      service_type,
      reference_type,
      amount,
      platform_fee,
      net_amount,
      status,
      provider,
      provider_transaction_id,
      reference_id,
      balance_after,
      wallet_id,
      metadata
    )
    values (
      p_supporter_profile_id,
      p_creator_profile_id,
      p_supporter_id,
      p_creator_profile_id,
      'debit',
      p_service_type,
      p_reference_type,
      p_amount,
      p_platform_fee,
      v_net_amount,
      'completed',
      p_provider,
      p_provider_transaction_id,
      v_supporter_reference_id,
      v_supporter_balance,
      case
        when p_provider = 'HobeNakiCoffee' then v_supporter_wallet_id
        else null
      end,
      jsonb_build_object('role', 'supporter') || p_metadata
    )
    returning id into v_supporter_tx_id;
  end if;

  -- ---------------------------------------------------
  -- 4. CREATOR SIDE (CREDIT)
  -- ---------------------------------------------------

  -- Ensure creator wallet exists
  insert into public.wallets (profile_id, balance)
  values (p_creator_profile_id, 0)
  on conflict (profile_id) do nothing;

  -- Lock creator wallet
  select id, balance
  into v_creator_wallet_id, v_creator_balance
  from public.wallets
  where profile_id = p_creator_profile_id
  for update;

  -- Credit creator wallet
  update public.wallets
  set balance = balance + v_net_amount,
      updated_at = now()
  where profile_id = p_creator_profile_id;

  v_creator_balance := v_creator_balance + v_net_amount;

  -- Insert creator transaction (CREDIT)
  insert into public.transactions (
    user_profile_id,
    counterparty_profile_id,
    supporter_id,
    creator_profile_id,
    direction,
    service_type,
    reference_type,
    amount,
    platform_fee,
    net_amount,
    status,
    provider,
    provider_transaction_id,
    reference_id,
    balance_after,
    wallet_id,
    metadata
  )
  values (
    p_creator_profile_id,
    p_supporter_profile_id,
    p_supporter_id,
    p_creator_profile_id,
    'credit',
    p_service_type,
    p_reference_type,
    p_amount,
    p_platform_fee,
    v_net_amount,
    'completed',
    p_provider,
    p_provider_transaction_id,
    v_creator_reference_id,
    v_creator_balance,
    case
      when p_provider = 'HobeNakiCoffee' then v_creator_wallet_id
      else null
    end,
    jsonb_build_object('role', 'creator') || p_metadata
  )
  returning id into v_creator_tx_id;

  -- ---------------------------------------------------
  -- 5. ACTIVITIES (UNIFIED FEED)
  -- ---------------------------------------------------

  -- Supporter activity (private) - only for authenticated supporters
  if p_supporter_profile_id is not null then
    insert into public.activities (
      transaction_id,
      reference_id,
      user_profile_id,
      counterparty_profile_id,
      role,
      service_type,
      metadata,
      visibility
    )
    values (
      v_supporter_tx_id,
      v_supporter_reference_id,
      p_supporter_profile_id,
      p_creator_profile_id,
      'supporter',
      p_service_type,
      jsonb_build_object(
        'type', p_service_type,
        'amount', p_amount,
        'supporter_id', p_supporter_id
      ) || p_metadata,
      'private'
    );
  end if;

  -- Creator activity (public)
  insert into public.activities (
    transaction_id,
    reference_id,
    user_profile_id,
    counterparty_profile_id,
    role,
    service_type,
    metadata,
    visibility
  )
  values (
    v_creator_tx_id,
    v_creator_reference_id,
    p_creator_profile_id,
    p_supporter_profile_id,
    'creator',
    p_service_type,
    jsonb_build_object(
      'type', p_service_type,
      'amount', v_net_amount,
      'supporter_id', p_supporter_id,
      'supporter_anonymous', p_supporter_profile_id is null
    ) || p_metadata,
    'public'
  );

  -- ---------------------------------------------------
  -- 6. Return structured response
  -- ---------------------------------------------------
  return jsonb_build_object(
    'success', true,
    'reference_id', v_creator_reference_id,
    'supporter_transaction_id', v_supporter_tx_id,
    'creator_transaction_id', v_creator_tx_id,
    'supporter_balance_after', v_supporter_balance,
    'creator_balance_after', v_creator_balance
  );

exception
  when others then
    raise exception '%', sqlerrm;
end;
$$;

