-- ---------------------------------------------------------
-- Follows table
-- ---------------------------------------------------------

create table public.follows (
  id bigint generated always as identity primary key,
  follower_id uuid references public.profiles(id) on delete cascade not null,
  following_id uuid references public.profiles(id) on delete cascade not null,
  created_at timestamptz default now(),

  constraint follows_unique_follower_following unique (follower_id, following_id),
  constraint follows_no_self_follow check (follower_id != following_id)
);

comment on table public.follows is 'Follow relationships between users';
comment on column public.follows.follower_id is 'The user who is following';
comment on column public.follows.following_id is 'The user being followed';

-- ---------------------------------------------------------
-- Indexes
-- ---------------------------------------------------------

create index idx_follows_follower_id on public.follows(follower_id);
create index idx_follows_following_id on public.follows(following_id);

-- ---------------------------------------------------------
-- Row Level Security
-- ---------------------------------------------------------

alter table public.follows enable row level security;

-- Public can read follows (for follower/following counts)
create policy "Anyone can read follows"
on public.follows
for select
to anon
using (true);

create policy "Authenticated users can read follows"
on public.follows
for select
to authenticated
using (true);

-- Authenticated users can create follows
create policy "Authenticated users can create follows"
on public.follows
for insert
to authenticated
with check (
  follower_id = (select auth.uid())
  and follower_id != following_id  -- prevent self-follow
);

-- Only the follower can delete their own follow
create policy "Follower can delete their own follow"
on public.follows
for delete
to authenticated
using (follower_id = (select auth.uid()));

-- ---------------------------------------------------------
-- Helper functions
-- ---------------------------------------------------------

create or replace function public.follow_user(target_user_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.follows (follower_id, following_id)
  values ((select auth.uid()), target_user_id)
  on conflict do nothing;
end;
$$;

comment on function public.follow_user(uuid) is 'Allows current user to follow target user';


create or replace function public.unfollow_user(target_user_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  delete from public.follows
  where follower_id = (select auth.uid())
    and following_id = target_user_id;
end;
$$;

comment on function public.unfollow_user(uuid) is 'Allows current user to unfollow target user';


create or replace function public.is_following(target_user_id uuid)
returns boolean
language plpgsql
stable
set search_path = ''
as $$
begin
  return exists (
    select 1 from public.follows
    where follower_id = (select auth.uid())
      and following_id = target_user_id
  );
end;
$$;

comment on function public.is_following(uuid) is 'Checks if current user is following target user';


create or replace function public.get_followers(target_user_id uuid)
returns setof uuid
language sql
stable
set search_path = ''
as $$
  select follower_id from public.follows where following_id = target_user_id;
$$;

comment on function public.get_followers(uuid) is 'Returns list of user IDs who follow the target user';


create or replace function public.get_following(target_user_id uuid)
returns setof uuid
language sql
stable
set search_path = ''
as $$
  select following_id from public.follows where follower_id = target_user_id;
$$;

comment on function public.get_following(uuid) is 'Returns list of user IDs that the target user follows';


create or replace function public.toggle_follow(target_user_id uuid)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare
  current_user_id uuid;
  is_following_record boolean;
begin
  current_user_id := (select auth.uid());

  if current_user_id = target_user_id then
    raise exception 'Cannot follow yourself';
  end if;

  select exists (
    select 1 from public.follows
    where follower_id = current_user_id
      and following_id = target_user_id
  ) into is_following_record;

  if is_following_record then
    delete from public.follows
    where follower_id = current_user_id
      and following_id = target_user_id;
    return false;
  else
    insert into public.follows (follower_id, following_id)
    values (current_user_id, target_user_id);
    return true;
  end if;
end;
$$;

comment on function public.toggle_follow(uuid) is 'Toggles follow status, returns true if now following, false if unfollowed';

-- ---------------------------------------------------------
-- Trigger functions for updating profile counts
-- ---------------------------------------------------------

create or replace function public.handle_follow()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  follower_profile record;
begin
  -- Increment following_count for follower
  update public.profiles
  set following_count = following_count + 1
  where id = new.follower_id;

  -- Increment follower_count for following
  update public.profiles
  set follower_count = follower_count + 1
  where id = new.following_id;

  -- Get follower profile info for activity
  select display_name, username into follower_profile
  from public.profiles
  where id = new.follower_id;

  -- Insert follow activity
  insert into public.activities (
    transaction_id,
    reference_id,
    user_profile_id,
    counterparty_profile_id,
    role,
    service_type,
    metadata,
    visibility
  ) values (
    null,
    gen_random_uuid(),
    new.following_id,
    new.follower_id,
    'creator',
    'follow',
    jsonb_build_object(
      'action', 'follow',
      'follower_name', follower_profile.display_name,
      'follower_username', follower_profile.username
    ),
    'public'
  );

  return new;
end;
$$;

create or replace function public.handle_unfollow()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  follower_profile record;
begin
  -- Decrement following_count for follower
  update public.profiles
  set following_count = following_count - 1
  where id = old.follower_id;

  -- Decrement follower_count for following
  update public.profiles
  set follower_count = follower_count - 1
  where id = old.following_id;

  -- Get follower profile info for activity
  select display_name, username into follower_profile
  from public.profiles
  where id = old.follower_id;

  -- Insert unfollow activity (private, only visible to the unfollowed user)
  insert into public.activities (
    transaction_id,
    reference_id,
    user_profile_id,
    counterparty_profile_id,
    role,
    service_type,
    metadata,
    visibility
  ) values (
    null,
    gen_random_uuid(),
    old.following_id,
    old.follower_id,
    'creator',
    'follow',
    jsonb_build_object(
      'action', 'unfollow',
      'follower_name', follower_profile.display_name,
      'follower_username', follower_profile.username
    ),
    'private'
  );

  return old;
end;
$$;

-- ---------------------------------------------------------
-- Triggers
-- ---------------------------------------------------------

create trigger on_follow_created
  after insert on public.follows
  for each row
  execute procedure public.handle_follow();

create trigger on_follow_deleted
  after delete on public.follows
  for each row
  execute procedure public.handle_unfollow();
