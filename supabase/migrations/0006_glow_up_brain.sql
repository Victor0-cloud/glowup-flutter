create extension if not exists pgcrypto;

-- ==================================================
-- 1. CONVERSATION THREADS
-- ==================================================

create table if not exists public.coach_threads (
    id uuid primary key default gen_random_uuid(),
    user_id uuid not null references auth.users(id) on delete cascade,
    title text,
    status text not null default 'active'
        check (status in ('active','archived')),
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now()
);

create index if not exists coach_threads_user_id_idx
    on public.coach_threads(user_id);

create index if not exists coach_threads_user_updated_idx
    on public.coach_threads(user_id, updated_at desc);


-- ==================================================
-- 2. CHAT MESSAGES
-- ==================================================

create table if not exists public.coach_messages (
    id uuid primary key default gen_random_uuid(),
    thread_id uuid not null
        references public.coach_threads(id)
        on delete cascade,
    user_id uuid not null
        references auth.users(id)
        on delete cascade,

    role text not null
        check (role in ('user','assistant','system')),

    content text not null,

    provider text,
    model text,

    input_tokens integer,
    output_tokens integer,

    created_at timestamptz not null default now()
);

create index if not exists coach_messages_thread_created_idx
    on public.coach_messages(thread_id, created_at);

create index if not exists coach_messages_user_created_idx
    on public.coach_messages(user_id, created_at desc);


-- ==================================================
-- 3. GLOW UP BRAIN EVENTS
-- Normalized activity stream from the entire app.
-- ==================================================

create table if not exists public.brain_events (
    id uuid primary key default gen_random_uuid(),
    user_id uuid not null
        references auth.users(id)
        on delete cascade,

    source text not null,

    event_type text not null,

    occurred_at timestamptz not null default now(),

    data jsonb not null default '{}'::jsonb,

    created_at timestamptz not null default now()
);

create index if not exists brain_events_user_time_idx
    on public.brain_events(user_id, occurred_at desc);

create index if not exists brain_events_user_source_idx
    on public.brain_events(user_id, source);

create index if not exists brain_events_data_gin_idx
    on public.brain_events using gin(data);


-- ==================================================
-- 4. LONG-TERM COACH MEMORY
-- Only durable user facts/preferences belong here.
-- ==================================================

create table if not exists public.coach_memory (
    id uuid primary key default gen_random_uuid(),

    user_id uuid not null
        references auth.users(id)
        on delete cascade,

    memory_key text not null,

    memory_value jsonb not null,

    category text not null default 'general',

    source text,

    confidence numeric(4,3)
        check (confidence is null or
               (confidence >= 0 and confidence <= 1)),

    is_active boolean not null default true,

    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now(),

    unique(user_id, memory_key)
);

create index if not exists coach_memory_user_active_idx
    on public.coach_memory(user_id, is_active);

create index if not exists coach_memory_value_gin_idx
    on public.coach_memory using gin(memory_value);


-- ==================================================
-- 5. USER FEEDBACK ON COACH RESPONSES
-- ==================================================

create table if not exists public.coach_feedback (
    id uuid primary key default gen_random_uuid(),

    user_id uuid not null
        references auth.users(id)
        on delete cascade,

    message_id uuid not null
        references public.coach_messages(id)
        on delete cascade,

    rating smallint
        check (rating in (-1,1)),

    feedback_text text,

    created_at timestamptz not null default now(),

    unique(user_id, message_id)
);

create index if not exists coach_feedback_user_idx
    on public.coach_feedback(user_id);


-- ==================================================
-- 6. REQUEST / AUDIT / DIAGNOSTICS
-- Do NOT store provider API keys here.
-- ==================================================

create table if not exists public.coach_request_log (
    id uuid primary key default gen_random_uuid(),

    user_id uuid references auth.users(id)
        on delete set null,

    thread_id uuid references public.coach_threads(id)
        on delete set null,

    request_id uuid not null default gen_random_uuid(),

    status text not null
        check (
            status in (
                'started',
                'completed',
                'rejected',
                'rate_limited',
                'provider_error',
                'internal_error'
            )
        ),

    provider text,
    model text,

    latency_ms integer,

    error_code text,

    created_at timestamptz not null default now()
);

create index if not exists coach_request_log_user_created_idx
    on public.coach_request_log(user_id, created_at desc);


-- ==================================================
-- UPDATED_AT TRIGGER
-- ==================================================

create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
    new.updated_at = now();
    return new;
end;
$$;

drop trigger if exists coach_threads_set_updated_at
on public.coach_threads;

create trigger coach_threads_set_updated_at
before update on public.coach_threads
for each row execute function public.set_updated_at();


drop trigger if exists coach_memory_set_updated_at
on public.coach_memory;

create trigger coach_memory_set_updated_at
before update on public.coach_memory
for each row execute function public.set_updated_at();


-- ==================================================
-- ROW LEVEL SECURITY
-- ==================================================

alter table public.coach_threads enable row level security;
alter table public.coach_messages enable row level security;
alter table public.brain_events enable row level security;
alter table public.coach_memory enable row level security;
alter table public.coach_feedback enable row level security;
alter table public.coach_request_log enable row level security;


-- THREADS

drop policy if exists "users read own coach threads"
on public.coach_threads;

create policy "users read own coach threads"
on public.coach_threads
for select
to authenticated
using (user_id = auth.uid());


drop policy if exists "users create own coach threads"
on public.coach_threads;

create policy "users create own coach threads"
on public.coach_threads
for insert
to authenticated
with check (user_id = auth.uid());


drop policy if exists "users update own coach threads"
on public.coach_threads;

create policy "users update own coach threads"
on public.coach_threads
for update
to authenticated
using (user_id = auth.uid())
with check (user_id = auth.uid());


drop policy if exists "users delete own coach threads"
on public.coach_threads;

create policy "users delete own coach threads"
on public.coach_threads
for delete
to authenticated
using (user_id = auth.uid());


-- MESSAGES

drop policy if exists "users read own coach messages"
on public.coach_messages;

create policy "users read own coach messages"
on public.coach_messages
for select
to authenticated
using (user_id = auth.uid());


drop policy if exists "users create own user messages"
on public.coach_messages;

create policy "users create own user messages"
on public.coach_messages
for insert
to authenticated
with check (
    user_id = auth.uid()
    and role = 'user'
    and exists (
        select 1
        from public.coach_threads t
        where t.id = thread_id
          and t.user_id = auth.uid()
    )
);


-- BRAIN EVENTS

drop policy if exists "users read own brain events"
on public.brain_events;

create policy "users read own brain events"
on public.brain_events
for select
to authenticated
using (user_id = auth.uid());


drop policy if exists "users create own brain events"
on public.brain_events;

create policy "users create own brain events"
on public.brain_events
for insert
to authenticated
with check (user_id = auth.uid());


-- MEMORY

drop policy if exists "users read own coach memory"
on public.coach_memory;

create policy "users read own coach memory"
on public.coach_memory
for select
to authenticated
using (user_id = auth.uid());


-- FEEDBACK

drop policy if exists "users read own coach feedback"
on public.coach_feedback;

create policy "users read own coach feedback"
on public.coach_feedback
for select
to authenticated
using (user_id = auth.uid());


drop policy if exists "users create own coach feedback"
on public.coach_feedback;

create policy "users create own coach feedback"
on public.coach_feedback
for insert
to authenticated
with check (
    user_id = auth.uid()
    and exists (
        select 1
        from public.coach_messages m
        where m.id = message_id
          and m.user_id = auth.uid()
          and m.role = 'assistant'
    )
);


drop policy if exists "users update own coach feedback"
on public.coach_feedback;

create policy "users update own coach feedback"
on public.coach_feedback
for update
to authenticated
using (user_id = auth.uid())
with check (user_id = auth.uid());


-- REQUEST LOG

drop policy if exists "users read own coach request log"
on public.coach_request_log;

create policy "users read own coach request log"
on public.coach_request_log
for select
to authenticated
using (user_id = auth.uid());


-- ==================================================
-- TABLE PRIVILEGES
-- RLS still controls which rows authenticated users
-- are actually permitted to access.
-- ==================================================

revoke all on table public.coach_threads from anon;
revoke all on table public.coach_messages from anon;
revoke all on table public.brain_events from anon;
revoke all on table public.coach_memory from anon;
revoke all on table public.coach_feedback from anon;
revoke all on table public.coach_request_log from anon;

grant select, insert, update, delete
on table public.coach_threads
to authenticated;

grant select, insert
on table public.coach_messages
to authenticated;

grant select, insert
on table public.brain_events
to authenticated;

grant select
on table public.coach_memory
to authenticated;

grant select, insert, update
on table public.coach_feedback
to authenticated;

grant select
on table public.coach_request_log
to authenticated;

-- Backend service role needs full access for the
-- secure Edge Function.
grant all privileges
on table public.coach_threads,
         public.coach_messages,
         public.brain_events,
         public.coach_memory,
         public.coach_feedback,
         public.coach_request_log
to service_role;
