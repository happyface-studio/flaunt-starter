-- Starter `posts` table matching SupabaseBackend.swift's DatabaseExampleView.
-- Replace or extend this with your own schema as the app grows.

create table if not exists public.posts (
    id uuid primary key default gen_random_uuid(),
    user_id uuid not null references auth.users (id) on delete cascade,
    content text not null check (char_length(content) <= 2000),
    created_at timestamptz not null default now()
);

create index if not exists posts_user_id_created_at_idx
    on public.posts (user_id, created_at desc);

alter table public.posts enable row level security;

create policy "posts_owner_select"
    on public.posts for select
    using (auth.uid() = user_id);

create policy "posts_owner_insert"
    on public.posts for insert
    with check (auth.uid() = user_id);

create policy "posts_owner_update"
    on public.posts for update
    using (auth.uid() = user_id)
    with check (auth.uid() = user_id);

create policy "posts_owner_delete"
    on public.posts for delete
    using (auth.uid() = user_id);
