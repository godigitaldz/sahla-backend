-- =============================================================================
-- Migration: Centralized Admin Alert Engine & Outbox Dispatches
-- Author: Sahla Systems Engineering
-- Date: 2026-11-16
-- Target: public.admin_alerts, public.admin_alert_dispatches
--
-- Rollback Instructions (Safe down-migration):
--   ALTER PUBLICATION supabase_realtime DROP TABLE IF EXISTS public.admin_alerts;
--   DROP TABLE IF EXISTS public.admin_alert_dispatches;
--   DROP TABLE IF EXISTS public.admin_alerts;
-- =============================================================================

BEGIN;

-- 1. Create admin_alerts table if not exists
CREATE TABLE IF NOT EXISTS public.admin_alerts (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  
  -- Entity References
  order_id uuid REFERENCES public.orders(id) ON DELETE CASCADE,
  task_id uuid REFERENCES public.tasks(id) ON DELETE CASCADE,
  
  -- Alert Classification
  alert_type varchar(64) NOT NULL,
  severity varchar(16) NOT NULL CHECK (severity IN ('critical', 'high', 'info')),
  
  -- Deduplication & Stable Incident Keys
  dedupe_key varchar(160) NOT NULL UNIQUE,
  incident_key varchar(160) DEFAULT NULL,
  
  -- Display Content
  title text NOT NULL,
  message text NOT NULL,
  metadata jsonb DEFAULT '{}'::jsonb,
  
  -- Lifecycle Status
  status varchar(24) NOT NULL DEFAULT 'active' 
    CHECK (status IN ('active', 'acknowledged', 'resolved', 'escalated', 'dismissed')),
  escalation_level int NOT NULL DEFAULT 0,
  
  -- Multi-Admin Acknowledgement Handshake
  acknowledged_by varchar(128) DEFAULT NULL,
  acknowledged_by_user_id uuid DEFAULT NULL,
  acknowledged_at timestamptz DEFAULT NULL,
  
  -- Resolution Tracking
  resolved_by varchar(128) DEFAULT NULL,
  resolved_at timestamptz DEFAULT NULL,
  resolution_reason varchar(64) DEFAULT NULL,
  
  -- Timestamps
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

-- Ensure incident_key column exists if table was partially created
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_schema = 'public' 
      AND table_name = 'admin_alerts' 
      AND column_name = 'incident_key'
  ) THEN
    ALTER TABLE public.admin_alerts ADD COLUMN incident_key varchar(160) DEFAULT NULL;
  END IF;
END $$;

-- 2. Create admin_alert_dispatches table for durable per-device outbox tracking
CREATE TABLE IF NOT EXISTS public.admin_alert_dispatches (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  alert_id uuid REFERENCES public.admin_alerts(id) ON DELETE CASCADE,
  incident_key varchar(160) NOT NULL,
  device_id varchar(128) NOT NULL,
  user_id uuid DEFAULT NULL,
  channel varchar(32) NOT NULL DEFAULT 'web_push' CHECK (channel IN ('web_push', 'fcm', 'desktop')),
  status varchar(32) NOT NULL DEFAULT 'queued' 
    CHECK (status IN ('queued', 'attempted', 'provider_accepted', 'failed', 'skipped')),
  attempt_count int NOT NULL DEFAULT 1,
  provider_status int DEFAULT NULL,
  provider_response jsonb DEFAULT '{}'::jsonb,
  error_message text DEFAULT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT uq_admin_alert_dispatch UNIQUE (incident_key, device_id, channel)
);

-- 3. Indexes for High-Frequency Operational Queries
CREATE INDEX IF NOT EXISTS idx_admin_alerts_status_created 
  ON public.admin_alerts(status, created_at DESC)
  WHERE status IN ('active', 'acknowledged', 'escalated');

CREATE INDEX IF NOT EXISTS idx_admin_alerts_order_id 
  ON public.admin_alerts(order_id) 
  WHERE order_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_admin_alerts_dedupe 
  ON public.admin_alerts(dedupe_key);

CREATE INDEX IF NOT EXISTS idx_admin_alerts_incident 
  ON public.admin_alerts(incident_key)
  WHERE incident_key IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_admin_alerts_type_status 
  ON public.admin_alerts(alert_type, status);

CREATE INDEX IF NOT EXISTS idx_admin_dispatches_incident 
  ON public.admin_alert_dispatches(incident_key, status);

-- 4. Row Level Security (RLS)
ALTER TABLE public.admin_alerts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.admin_alert_dispatches ENABLE ROW LEVEL SECURITY;

-- Service role has unrestricted access (backend uses service role)
DROP POLICY IF EXISTS "service_role_admin_alerts_all" ON public.admin_alerts;
CREATE POLICY "service_role_admin_alerts_all" 
  ON public.admin_alerts 
  FOR ALL 
  TO service_role 
  USING (true) 
  WITH CHECK (true);

DROP POLICY IF EXISTS "service_role_admin_dispatches_all" ON public.admin_alert_dispatches;
CREATE POLICY "service_role_admin_dispatches_all" 
  ON public.admin_alert_dispatches 
  FOR ALL 
  TO service_role 
  USING (true) 
  WITH CHECK (true);

-- Performance dashboard client connects with anon key to Supabase Realtime
DROP POLICY IF EXISTS "anon_read_alerts" ON public.admin_alerts;
CREATE POLICY "anon_read_alerts" 
  ON public.admin_alerts 
  FOR SELECT 
  TO anon 
  USING (true);

-- Authenticated admins can read alerts
DROP POLICY IF EXISTS "admins_read_alerts" ON public.admin_alerts;
CREATE POLICY "admins_read_alerts" 
  ON public.admin_alerts 
  FOR SELECT 
  TO authenticated 
  USING (
    EXISTS (
      SELECT 1 FROM public.user_profiles
      WHERE user_profiles.id = auth.uid()
        AND (user_profiles.role ILIKE 'admin' OR user_profiles.role = 'super_admin')
    )
  );

-- Authenticated admins can update acknowledgement/resolution
DROP POLICY IF EXISTS "admins_update_alerts" ON public.admin_alerts;
CREATE POLICY "admins_update_alerts" 
  ON public.admin_alerts 
  FOR UPDATE 
  TO authenticated 
  USING (
    EXISTS (
      SELECT 1 FROM public.user_profiles
      WHERE user_profiles.id = auth.uid()
        AND (user_profiles.role ILIKE 'admin' OR user_profiles.role = 'super_admin')
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.user_profiles
      WHERE user_profiles.id = auth.uid()
        AND (user_profiles.role ILIKE 'admin' OR user_profiles.role = 'super_admin')
    )
  );

-- 5. Enable Supabase Realtime Publication for admin_alerts
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables 
    WHERE pubname = 'supabase_realtime' 
      AND schemaname = 'public' 
      AND tablename = 'admin_alerts'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.admin_alerts;
  END IF;
EXCEPTION
  WHEN OTHERS THEN
    RAISE NOTICE 'Could not add admin_alerts to supabase_realtime publication: %', SQLERRM;
END $$;

COMMIT;
