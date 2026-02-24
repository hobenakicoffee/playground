-- ---------------------------------------------------------
-- messaging tables
-- ---------------------------------------------------------

create table if not exists public.conversations (
  id uuid primary key default gen_random_uuid(),
  type text not null default 'direct',
  name text,
  created_at timestamptz not null default now(),
  last_message_at timestamptz,
  last_message_preview text
);

comment on table public.conversations is 'Chat conversations (direct or group)';
comment on column public.conversations.type is 'Type of conversation: direct or group';
comment on column public.conversations.name is 'Name for group conversations';

create table if not exists public.conversation_participants (
  conversation_id uuid not null references public.conversations(id) on delete cascade,
  profile_id uuid not null references public.profiles(id) on delete cascade,
  last_read_at timestamptz,
  joined_at timestamptz not null default now(),
  primary key (conversation_id, profile_id)
);

comment on table public.conversation_participants is 'Users participating in conversations';
comment on column public.conversation_participants.profile_id is 'Profile ID of the participant';

create table if not exists public.messages (
  id bigserial primary key,
  conversation_id uuid not null references public.conversations(id) on delete cascade,
  sender_id uuid not null references public.profiles(id) on delete cascade,
  content text not null check (length(content) <= 5000),
  created_at timestamptz not null default now()
);

comment on table public.messages is 'Messages within conversations';
comment on column public.messages.sender_id is 'Profile ID of the message sender';

-- ---------------------------------------------------------
-- indexes
-- ---------------------------------------------------------

create index if not exists idx_messages_conversation_created_at
on public.messages (conversation_id, created_at desc);

create index if not exists idx_conversations_last_message_at
on public.conversations (last_message_at desc);

create index if not exists idx_participants_profile
on public.conversation_participants (profile_id);

create index if not exists idx_participants_conversation
on public.conversation_participants (conversation_id);

-- ---------------------------------------------------------
-- trigger: update last_message_at and last_message_preview
-- ---------------------------------------------------------

create or replace function public.update_last_message_at()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  update public.conversations
  set
    last_message_at = new.created_at,
    last_message_preview = left(new.content, 100)
  where id = new.conversation_id;

  return new;
end;
$$;

drop trigger if exists trg_update_last_message_at on public.messages;

create trigger trg_update_last_message_at
after insert on public.messages
for each row
execute function public.update_last_message_at();

-- ---------------------------------------------------------
-- row level security
-- ---------------------------------------------------------

alter table public.conversations enable row level security;
alter table public.conversation_participants enable row level security;
alter table public.messages enable row level security;

-- ---------------------------------------------------------
-- rls policies: conversations
-- ---------------------------------------------------------

create policy "Users can view their conversations"
on public.conversations
for select
using (
  exists (
    select 1 from public.conversation_participants cp
    where cp.conversation_id = conversations.id
    and cp.profile_id = (select auth.uid())
  )
);

-- ---------------------------------------------------------
-- rls policies: conversation_participants
-- ---------------------------------------------------------

create policy "Users can view participants of their conversations"
on public.conversation_participants
for select
using (
  exists (
    select 1 from public.conversation_participants cp
    where cp.conversation_id = conversation_participants.conversation_id
    and cp.profile_id = (select auth.uid())
  )
);

create policy "Users can insert themselves as participant"
on public.conversation_participants
for insert
with check (
  profile_id = (select auth.uid())
);

-- ---------------------------------------------------------
-- rls policies: messages
-- ---------------------------------------------------------

create policy "Users can view messages in their conversations"
on public.messages
for select
using (
  exists (
    select 1 from public.conversation_participants cp
    where cp.conversation_id = messages.conversation_id
    and cp.profile_id = (select auth.uid())
  )
);

create policy "Users can send messages in their conversations"
on public.messages
for insert
with check (
  sender_id = (select auth.uid())
  and exists (
    select 1 from public.conversation_participants cp
    where cp.conversation_id = messages.conversation_id
    and cp.profile_id = (select auth.uid())
  )
);
