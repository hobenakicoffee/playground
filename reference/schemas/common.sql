-- ---------------------------------------------------------
-- enums
-- ---------------------------------------------------------

create type public.supporter_platform_enum as enum (
  'facebook',
  'x',
  'instagram',
  'youtube',
  'github',
  'linkedin',
  'twitch',
  'tiktok',
  'threads',
  'whatsapp',
  'telegram',
  'discord',
  'reddit',
  'pinterest',
  'medium',
  'devto',
  'behance',
  'dribbble'
);

create type public.payment_status_enum as enum (
  'pending',
  'processing',
  'completed',
  'failed',
  'reversed',
  'cancelled',
  'refunded',
  'reviewing'
);

create type public.reference_type_enum as enum (
  'subscription',
  'one-time',
  'payout',
  'withdraw_lock',
  'withdraw_release',
  'withdraw_complete',
  'manual_adjustment'
);

create type public.payout_provider as enum (
  'bkash',
  'nagad',
  'rocket',
  'bank'
);

create type public.withdrawal_status as enum (
  'requested',
  'approved',
  'processing',
  'paid',
  'rejected',
  'failed'
);

create type public.transaction_direction_enum as enum (
  'debit',
  'credit'
);

create type public.provider_enum as enum (
  'HobeNakiCoffee',
  'Bkash',
  'Nagad',
  'Rocket',
  'Upay',
  'SSLCommerz',
  'Aamarpay',
  'Portwallet',
  'Tap',
  'Other'
);

create type public.visibility_enum as enum (
  'public',
  'private'
);

-- ---------------------------------------------------------
-- functions
-- ---------------------------------------------------------

create or replace function public.handle_updated_at()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;
