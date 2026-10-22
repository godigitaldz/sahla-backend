-- Event-driven order lifecycle schema (Supabase Postgres)
-- Apply with your normal migration workflow.

-- 1) Orders lifecycle metadata (optional extension of existing table)
alter table if exists public.orders
  add column if not exists accepted_at timestamptz,
  add column if not exists picked_up_at timestamptz,
  add column if not exists delivered_at timestamptz,
  add column if not exists cancelled_at timestamptz,
  add column if not exists cancel_reason text,
  add column if not exists zone_geojson jsonb,
  add column if not exists lifecycle_version integer not null default 0;

-- 2) Scheduled lifecycle jobs ledger
create table if not exists public.order_lifecycle_jobs (
  id uuid primary key default gen_random_uuid(),
  order_id uuid not null references public.orders(id) on delete cascade,
  job_key text not null unique,
  event_type text not null,
  qstash_message_id text,
  scheduled_for timestamptz not null,
  state text not null default 'scheduled' check (state in ('scheduled','executed','skipped','failed','cancelled')),
  attempt_count integer not null default 0,
  last_error text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  executed_at timestamptz
);

create index if not exists idx_order_lifecycle_jobs_order_id
  on public.order_lifecycle_jobs(order_id);
create index if not exists idx_order_lifecycle_jobs_state_time
  on public.order_lifecycle_jobs(state, scheduled_for);

-- 3) Immutable order lifecycle event log (idempotency anchor)
create table if not exists public.order_events (
  id uuid primary key default gen_random_uuid(),
  event_id text not null unique,
  order_id uuid not null references public.orders(id) on delete cascade,
  event_type text not null,
  source text not null default 'backend',
  payload_json jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create index if not exists idx_order_events_order_id_created_at
  on public.order_events(order_id, created_at desc);

-- 4) Push dispatch dedupe + audit log
create table if not exists public.notification_dispatch_log (
  id uuid primary key default gen_random_uuid(),
  dispatch_key text not null unique,
  order_id uuid references public.orders(id) on delete set null,
  cohort text not null check (cohort in ('admin','user')),
  channel text not null default 'push',
  status text not null default 'sent' check (status in ('sent','skipped','failed')),
  provider_response jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists idx_notification_dispatch_order_id
  on public.notification_dispatch_log(order_id);
