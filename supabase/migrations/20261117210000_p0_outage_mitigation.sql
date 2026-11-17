-- =============================================================================
-- Migration: P0 Production Outage Mitigation & Concurrency Hardening
-- Date: 2026-11-17
-- Focus:
--   1. Expression index on push_notifications_log((data->>'order_id'), (data->>'flow'))
--   2. Atomic PostgreSQL distributed lock for serverless background workers
--   3. Aggressive autovacuum tuning on high-churn tables (orders, delivery_personnel, jobs)
-- =============================================================================

BEGIN;

-- -----------------------------------------------------------------------------
-- 1) Expression Index for Poller Dedupe & Lookup on push_notifications_log
-- Eliminates the 73k-tuple sequential/bitmap scan on every 2-minute poller tick.
-- -----------------------------------------------------------------------------
CREATE INDEX IF NOT EXISTS idx_push_notifications_log_order_id_flow
  ON public.push_notifications_log ((data->>'order_id'), (data->>'flow'))
  WHERE status = 'sent';

-- Also index order_id alone for queries filtering only by order_id
CREATE INDEX IF NOT EXISTS idx_push_notifications_log_order_id
  ON public.push_notifications_log ((data->>'order_id'))
  WHERE status = 'sent';

-- -----------------------------------------------------------------------------
-- 2) Serverless-Safe Distributed Lock Storage & Atomic Functions
-- Replaces ephemeral in-memory Map() with durable, lease-based database locking.
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.system_distributed_locks (
  lock_key text PRIMARY KEY,
  acquired_at timestamptz NOT NULL DEFAULT now(),
  expires_at timestamptz NOT NULL,
  holder_id text,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb
);

CREATE INDEX IF NOT EXISTS idx_system_distributed_locks_expiry
  ON public.system_distributed_locks (expires_at);

ALTER TABLE public.system_distributed_locks ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE public.system_distributed_locks FROM PUBLIC;
REVOKE ALL ON TABLE public.system_distributed_locks FROM anon, authenticated;
GRANT ALL ON TABLE public.system_distributed_locks TO service_role;

CREATE OR REPLACE FUNCTION public.acquire_distributed_lock(
  p_key text,
  p_ttl_ms integer,
  p_holder_id text DEFAULT NULL
)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_now timestamptz := clock_timestamp();
  v_ttl_ms integer := greatest(coalesce(p_ttl_ms, 60000), 1000);
  v_expires_at timestamptz := v_now + (v_ttl_ms::text || ' milliseconds')::interval;
  v_acquired boolean := false;
BEGIN
  -- Serialize lock attempts on the specific key across concurrent transactions
  PERFORM pg_advisory_xact_lock(hashtext(p_key));

  -- Insert new lock, or overwrite existing lock IF AND ONLY IF it has expired
  INSERT INTO public.system_distributed_locks (lock_key, acquired_at, expires_at, holder_id)
  VALUES (p_key, v_now, v_expires_at, p_holder_id)
  ON CONFLICT (lock_key) DO UPDATE
    SET acquired_at = EXCLUDED.acquired_at,
        expires_at = EXCLUDED.expires_at,
        holder_id = EXCLUDED.holder_id
    WHERE public.system_distributed_locks.expires_at <= v_now;

  GET DIAGNOSTICS v_acquired = ROW_COUNT;
  RETURN (v_acquired > 0);
END;
$$;

CREATE OR REPLACE FUNCTION public.release_distributed_lock(
  p_key text,
  p_holder_id text DEFAULT NULL
)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  DELETE FROM public.system_distributed_locks
  WHERE lock_key = p_key
    AND (p_holder_id IS NULL OR holder_id = p_holder_id);
  RETURN FOUND;
END;
$$;

REVOKE ALL ON FUNCTION public.acquire_distributed_lock(text, integer, text) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.release_distributed_lock(text, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.acquire_distributed_lock(text, integer, text) TO service_role;
GRANT EXECUTE ON FUNCTION public.release_distributed_lock(text, text) TO service_role;

-- -----------------------------------------------------------------------------
-- 3) Autovacuum Tuning on High-Churn Tables
-- Prevents 100% dead tuple accumulation and table bloat on orders and couriers.
-- -----------------------------------------------------------------------------
ALTER TABLE IF EXISTS public.orders SET (
  autovacuum_vacuum_scale_factor = 0.05,
  autovacuum_vacuum_cost_limit = 1000,
  autovacuum_vacuum_threshold = 50
);

ALTER TABLE IF EXISTS public.delivery_personnel SET (
  autovacuum_vacuum_scale_factor = 0.05,
  autovacuum_vacuum_cost_limit = 1000,
  autovacuum_vacuum_threshold = 20
);

ALTER TABLE IF EXISTS public.order_lifecycle_jobs SET (
  autovacuum_vacuum_scale_factor = 0.05,
  autovacuum_vacuum_threshold = 50
);

ALTER TABLE IF EXISTS public.notification_dispatch_log SET (
  autovacuum_vacuum_scale_factor = 0.05,
  autovacuum_vacuum_threshold = 50
);

COMMIT;

NOTIFY pgrst, 'reload schema';
