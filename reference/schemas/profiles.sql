create type public.user_role as enum ('user', 'admin');

comment on type public.user_role is 'Available user roles for access control';

-- ---------------------------------------------------------
-- profiles table
-- ---------------------------------------------------------

create table public.profiles (
  id uuid primary key references auth.users on delete cascade,
  full_name text,

  -- public identity
  username text unique not null,
  display_name text,
  bio text,
  avatar_url text,
  banner_url text,

  -- public page
  page_slug text unique not null,

  -- role based access control
  role public.user_role not null default 'user',

  -- profile customization
  theme jsonb,    -- colors, fonts
  layout jsonb,   -- page builder layout

  -- feature flags (mvp-safe)
  allow_gifting boolean default true,
  allow_subscriptions boolean default true,
  is_page_active boolean default true,
  has_wallet_balance boolean default false,

  -- social links
  social_links jsonb default '[]'::jsonb,

  -- thank you dialog items (shown after successful gifting)
  thank_you_items jsonb default '[]'::jsonb,

  -- follow counts
  follower_count bigint default 0,
  following_count bigint default 0,

  created_at timestamptz default now(),
  updated_at timestamptz default now(),

  constraint username_length check (char_length(username) between 3 and 50),
  constraint follower_count_not_negative check (follower_count >= 0),
  constraint following_count_not_negative check (following_count >= 0)
);

comment on table public.profiles is 'public user profiles linked 1:1 with auth.users';
comment on column public.profiles.follower_count is 'Number of users following this profile';
comment on column public.profiles.following_count is 'Number of users this profile is following';

-- ---------------------------------------------------------
-- helper function: check if user is admin
-- ---------------------------------------------------------

create or replace function public.is_admin()
returns boolean
language sql
security definer
stable
set search_path = ''
as $$
  select exists (
    select 1 from public.profiles
    where id = (select auth.uid())
    and role = 'admin'
  );
$$;

-- ---------------------------------------------------------
-- row level security
-- ---------------------------------------------------------

alter table public.profiles enable row level security;

-- ---------------------------------------------------------
-- rls policies: select
-- ---------------------------------------------------------

-- public can read profiles (for public pages)
create policy "Anyone can view all profiles"
on public.profiles
for select
to anon
using (true);

create policy "Authenticated users can view all profiles"
on public.profiles
for select
to authenticated
using (true);

-- ---------------------------------------------------------
-- rls policies: insert
-- ---------------------------------------------------------

-- only the authenticated user can create their profile
create policy "Users can create their own profile"
on public.profiles
for insert
to authenticated
with check (
  id = (select auth.uid())
  and role = 'user'  -- force user role on creation
);

-- ---------------------------------------------------------
-- rls policies: update
-- ---------------------------------------------------------

-- combined policy: users can update their own profile, admins can update any profile
create policy "Users can update own profile, admins can update any"
on public.profiles
for update
to authenticated
using (
  id = (select auth.uid()) or public.is_admin()
)
with check (
  (
    -- regular users: update own profile without changing role
    id = (select auth.uid())
    and role = (select role from public.profiles where id = (select auth.uid()))
  )
  or
  -- admins: update any profile including role
  public.is_admin()
);

-- ---------------------------------------------------------
-- rls policies: delete
-- ---------------------------------------------------------

-- combined policy: users can delete their own profile, admins can delete any profile
create policy "Users can delete own profile, admins can delete any"
on public.profiles
for delete
to authenticated
using (
  id = (select auth.uid()) or public.is_admin()
);

-- ---------------------------------------------------------
-- indexes
-- ---------------------------------------------------------

create index idx_profiles_page_slug on public.profiles(page_slug);
create index idx_profiles_username on public.profiles(username);
create index idx_profiles_follower_count on public.profiles(follower_count);
create index idx_profiles_following_count on public.profiles(following_count);

-- ---------------------------------------------------------
-- trigger for auto-updating updated_at
-- ---------------------------------------------------------

create trigger on_profile_updated
  before update on public.profiles
  for each row
  execute procedure public.handle_updated_at();

-- ---------------------------------------------------------
-- trigger for auto-creating profiles
-- ---------------------------------------------------------

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.profiles (id, username, page_slug, role, full_name, avatar_url)
  values (
    new.id,
    new.id::text,   -- use UUID string for username
    new.id::text,   -- use same UUID string for page_slug
    'user',         -- default role
    new.raw_user_meta_data->>'full_name',
    new.raw_user_meta_data->>'avatar_url'
  );
  return new;
end;
$$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row
  execute procedure public.handle_new_user();

-- ---------------------------------------------------------
-- storage buckets
-- ---------------------------------------------------------

insert into storage.buckets (id, name, public)
  values
    ('avatars', 'avatars', true),
    ('banners', 'banners', true);

-- ---------------------------------------------------------
-- storage rls policies: avatars bucket
-- ---------------------------------------------------------

create policy "Avatar images are publicly accessible"
on storage.objects
for select
using (bucket_id = 'avatars');

create policy "Authenticated users can upload avatars"
on storage.objects
for insert
to authenticated
with check (
  bucket_id = 'avatars'
  and (storage.foldername(name))[1] = (select auth.uid())::text
);

create policy "Users can update their own avatars"
on storage.objects
for update
to authenticated
using (bucket_id = 'avatars' and (select auth.uid()) = owner)
with check (bucket_id = 'avatars' and (select auth.uid()) = owner);

create policy "Users can delete their own avatars"
on storage.objects
for delete
to authenticated
using (bucket_id = 'avatars' and (select auth.uid()) = owner);

create policy "Admins can upload any avatar"
on storage.objects
for insert
to authenticated
with check (bucket_id = 'avatars' and public.is_admin());

create policy "Admins can update any avatar"
on storage.objects
for update
to authenticated
using (bucket_id = 'avatars' and public.is_admin())
with check (bucket_id = 'avatars' and public.is_admin());

create policy "Admins can delete any avatar"
on storage.objects
for delete
to authenticated
using (bucket_id = 'avatars' and public.is_admin());

-- ---------------------------------------------------------
-- storage rls policies: banners bucket
-- ---------------------------------------------------------

create policy "Banner images are publicly accessible"
on storage.objects
for select
using (bucket_id = 'banners');

create policy "Authenticated users can upload banners"
on storage.objects
for insert
to authenticated
with check (
  bucket_id = 'banners'
  and (storage.foldername(name))[1] = (select auth.uid())::text
);

create policy "Users can update their own banners"
on storage.objects
for update
to authenticated
using (bucket_id = 'banners' and (select auth.uid()) = owner)
with check (bucket_id = 'banners' and (select auth.uid()) = owner);

create policy "Users can delete their own banners"
on storage.objects
for delete
to authenticated
using (bucket_id = 'banners' and (select auth.uid()) = owner);

create policy "Admins can upload any banner"
on storage.objects
for insert
to authenticated
with check (bucket_id = 'banners' and public.is_admin());

create policy "Admins can update any banner"
on storage.objects
for update
to authenticated
using (bucket_id = 'banners' and public.is_admin())
with check (bucket_id = 'banners' and public.is_admin());

create policy "Admins can delete any banner"
on storage.objects
for delete
to authenticated
using (bucket_id = 'banners' and public.is_admin());
