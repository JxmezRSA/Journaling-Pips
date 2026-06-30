-- Journaling Pips Version 3 Sprint 17 cloud schema.
-- Apply manually in the Supabase SQL editor.
-- Security rule: only SUPABASE_URL and SUPABASE_ANON_KEY belong in the iOS app.
-- Never place a service role key or OpenAI key in the app bundle.

create extension if not exists pgcrypto;

create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  email text not null,
  display_name text default '',
  subscription_tier text not null default 'Free',
  profile_image_path text,
  trading_experience text default '',
  trading_style text default '',
  preferred_markets text default '',
  account_size numeric not null default 0,
  currency text not null default 'USD',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.trades (
  id uuid primary key,
  user_id uuid not null references auth.users(id) on delete cascade,
  pair text not null,
  direction text not null,
  entry_price numeric not null default 0,
  stop_loss numeric not null default 0,
  take_profit numeric not null default 0,
  profit_loss numeric not null default 0,
  notes text default '',
  exit_price numeric not null default 0,
  lot_size numeric not null default 0,
  risk_percent numeric not null default 0,
  date timestamptz not null,
  status text not null,
  risk_reward numeric not null default 0,
  session text default '',
  strategy text default '',
  mistake_tags jsonb not null default '[]',
  confidence numeric not null default 5,
  emotion text default '',
  execution_score integer not null default 0,
  followed_plan boolean not null default true,
  trade_thesis text default '',
  market_context text default '',
  execution_review text default '',
  lessons_learned text default '',
  screenshot_count integer not null default 0,
  remote_updated_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.ai_reviews (
  id uuid primary key,
  user_id uuid not null references auth.users(id) on delete cascade,
  trade_id uuid references public.trades(id) on delete cascade,
  overall_score integer not null default 0,
  grade text default '',
  summary text default '',
  strengths jsonb not null default '[]',
  improvements jsonb not null default '[]',
  execution_score integer not null default 0,
  risk_score integer not null default 0,
  psychology_score integer not null default 0,
  journal_quality_score integer not null default 0,
  strategy_discipline_score integer not null default 0,
  payload jsonb not null default '{}',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.morning_plans (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  plan_date date not null,
  market_bias text default 'Neutral',
  checklist jsonb not null default '[]',
  watchlist jsonb not null default '[]',
  goals jsonb not null default '[]',
  risk_plan jsonb not null default '{}',
  notes text default '',
  payload jsonb not null default '{}',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(user_id, plan_date)
);

create table if not exists public.daily_reviews (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  review_date date not null,
  total_pl numeric not null default 0,
  trade_count integer not null default 0,
  win_rate numeric not null default 0,
  payload jsonb not null default '{}',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(user_id, review_date)
);

create table if not exists public.insights (
  id uuid primary key,
  user_id uuid not null references auth.users(id) on delete cascade,
  related_trade_id uuid references public.trades(id) on delete set null,
  title text not null,
  subtitle text not null,
  icon text not null,
  priority integer not null default 0,
  category text not null,
  confidence numeric not null default 0,
  is_read boolean not null default false,
  fingerprint text not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(user_id, fingerprint)
);

create table if not exists public.settings (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  payload jsonb not null default '{}',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(user_id)
);

create table if not exists public.sync_queue (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  entity_id uuid not null,
  entity_type text not null,
  operation text not null,
  status text not null default 'Waiting',
  attempts integer not null default 0,
  last_error text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.screenshot_assets (
  id uuid primary key,
  user_id uuid not null references auth.users(id) on delete cascade,
  trade_id uuid not null references public.trades(id) on delete cascade,
  slot text not null,
  storage_path text not null,
  byte_count integer not null default 0,
  created_at timestamptz not null default now(),
  unique(user_id, trade_id, slot)
);

alter table public.profiles enable row level security;
alter table public.trades enable row level security;
alter table public.ai_reviews enable row level security;
alter table public.morning_plans enable row level security;
alter table public.daily_reviews enable row level security;
alter table public.insights enable row level security;
alter table public.settings enable row level security;
alter table public.sync_queue enable row level security;
alter table public.screenshot_assets enable row level security;

create policy "profiles_select_own" on public.profiles for select using (auth.uid() = id);
create policy "profiles_insert_own" on public.profiles for insert with check (auth.uid() = id);
create policy "profiles_update_own" on public.profiles for update using (auth.uid() = id) with check (auth.uid() = id);

create policy "trades_crud_own" on public.trades for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy "ai_reviews_crud_own" on public.ai_reviews for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy "morning_plans_crud_own" on public.morning_plans for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy "daily_reviews_crud_own" on public.daily_reviews for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy "insights_crud_own" on public.insights for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy "settings_crud_own" on public.settings for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy "sync_queue_crud_own" on public.sync_queue for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy "screenshot_assets_crud_own" on public.screenshot_assets for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
