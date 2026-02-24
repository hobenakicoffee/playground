/*
  migration: create_supporters_table
  purpose:
    - tracks supporters who have gifted coffee to creators
    - aggregates support metrics per supporter-creator relationship
    - supports both authenticated and anonymous supporters
    - deduplicates supporters using identity_hash
  notes:
    - user_profile_id is nullable for anonymous supporters
    - identity_hash = hash(creator_id + display_name + client_ip + user_agent)
    - unique per creator to deduplicate anonymous supporters
    - name is automatically updated via trigger when user profile changes
*/

-- ---------------------------------------------------------
-- supporters
-- ---------------------------------------------------------

create table public.supporters (
  id uuid primary key default gen_random_uuid(),

  -- authenticated supporter (nullable for anonymous)
  user_profile_id uuid references public.profiles(id) on delete set null,

  -- creator being supported
  creator_id uuid not null references public.profiles(id) on delete cascade,

  -- supporter display identity
  name varchar not null,
  social_platform public.supporter_platform_enum,

  -- support metrics
  first_supported_at timestamptz,
  last_supported_at timestamptz,
  total_amount bigint not null default 0 check (total_amount >= 0),
  support_count integer not null default 0 check (support_count >= 0),
  last_supported_service varchar,

  -- deduplication key
  identity_hash varchar not null,

  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),

  -- enforce unique supporter per creator (for authenticated users)
  constraint supporters_unique_user_creator
  unique (user_profile_id, creator_id),

  -- enforce unique identity per creator (for anonymous deduplication)
  constraint supporters_unique_identity_per_creator
  unique (creator_id, identity_hash)
);

comment on table public.supporters is
'aggregates supporter relationships and gift metrics per creator';

alter table public.supporters enable row level security;

-- SELECT policies
-- Authenticated users can view all supporters
create policy "Authenticated users can view supporters"
on public.supporters
for select
to authenticated
using (true);

-- UPDATE policies
-- Only the creator can update their supporters (via backend logic)
create policy "Creators can update their supporters"
on public.supporters
for update
to authenticated
using (creator_id = (select auth.uid()));

create index idx_supporters_creator_id
on public.supporters(creator_id);

create index idx_supporters_user_profile_id
on public.supporters(user_profile_id);

create index idx_supporters_identity_hash
on public.supporters(identity_hash);

create index idx_supporters_last_supported_at
on public.supporters(last_supported_at desc);

-- ---------------------------------------------------------
-- trigger for auto-updating updated_at
-- ---------------------------------------------------------

create trigger on_supporter_updated
  before update on public.supporters
  for each row
  execute procedure public.handle_updated_at();

-- ---------------------------------------------------------
-- upsert_supporter function
-- ---------------------------------------------------------

create or replace function public.upsert_supporter(
  p_creator_id uuid,
  p_name varchar,
  p_identity_hash varchar,
  p_user_profile_id uuid default null,
  p_social_platform public.supporter_platform_enum default null,
  p_amount bigint default 0,
  p_service_type varchar default null
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_supporter_id uuid;
begin
  -- ---------------------------------------------------
  -- 1. Input validation
  -- ---------------------------------------------------
  if p_creator_id is null then
    raise exception 'Creator ID is required';
  end if;

  if p_name is null or p_name = '' then
    raise exception 'Supporter name is required';
  end if;

  if p_identity_hash is null or p_identity_hash = '' then
    raise exception 'Identity hash is required';
  end if;

  if p_amount < 0 then
    raise exception 'Amount cannot be negative';
  end if;

  -- ---------------------------------------------------
  -- 2. Upsert supporter record
  -- ---------------------------------------------------
  if p_user_profile_id is not null then
    insert into public.supporters (
      user_profile_id,
      creator_id,
      name,
      social_platform,
      first_supported_at,
      last_supported_at,
      total_amount,
      support_count,
      last_supported_service,
      identity_hash
    )
    values (
      p_user_profile_id,
      p_creator_id,
      p_name,
      p_social_platform,
      now(),
      now(),
      p_amount,
      1,
      p_service_type,
      p_identity_hash
    )
    on conflict (user_profile_id, creator_id)
    do update set
      name = excluded.name,
      social_platform = excluded.social_platform,
      last_supported_at = now(),
      total_amount = supporters.total_amount + excluded.total_amount,
      support_count = supporters.support_count + 1,
      last_supported_service = excluded.last_supported_service,
      identity_hash = excluded.identity_hash,
      updated_at = now()
    returning id into v_supporter_id;
  else
    insert into public.supporters (
      user_profile_id,
      creator_id,
      name,
      social_platform,
      first_supported_at,
      last_supported_at,
      total_amount,
      support_count,
      last_supported_service,
      identity_hash
    )
    values (
      p_user_profile_id,
      p_creator_id,
      p_name,
      p_social_platform,
      now(),
      now(),
      p_amount,
      1,
      p_service_type,
      p_identity_hash
    )
    on conflict (creator_id, identity_hash)
    do update set
      user_profile_id = coalesce(excluded.user_profile_id, supporters.user_profile_id),
      name = excluded.name,
      social_platform = excluded.social_platform,
      last_supported_at = now(),
      total_amount = supporters.total_amount + excluded.total_amount,
      support_count = supporters.support_count + 1,
      last_supported_service = excluded.last_supported_service,
      updated_at = now()
    returning id into v_supporter_id;
  end if;

  -- ---------------------------------------------------
  -- 3. Return supporter ID
  -- ---------------------------------------------------
  return v_supporter_id;

exception
  when others then
    raise exception '%', sqlerrm;
end;
$$;
