-- =============================================================================
-- Migration: Centralized Admin Alert Engine
-- Author: Sahla Systems Engineering
-- Date: 2026-11-16
-- Target: public.admin_alerts and user_device_tokens platform expansion
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
  
  -- Deduplication Key: Prevents duplicate alert records for the same breach episode
  -- format: 'order:<uuid>:<alert_type>:<timestamp_hash>'
  dedupe_key varchar(160) NOT NULL UNIQUE,
  
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

-- 2. Indexes for High-Frequency Operational Queries
CREATE INDEX IF NOT EXISTS idx_admin_alerts_status_created 
  ON public.admin_alerts(status, created_at DESC)
  WHERE status IN ('active', 'acknowledged', 'escalated');

CREATE INDEX IF NOT EXISTS idx_admin_alerts_order_id 
  ON public.admin_alerts(order_id) 
  WHERE order_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_admin_alerts_dedupe 
  ON public.admin_alerts(dedupe_key);

CREATE INDEX IF NOT EXISTS idx_admin_alerts_type_status 
  ON public.admin_alerts(alert_type, status);

-- 3. Row Level Security (RLS)
ALTER TABLE public.admin_alerts ENABLE ROW LEVEL SECURITY;

-- Service role has unrestricted access (backend uses service role)
DROP POLICY IF EXISTS "service_role_admin_alerts_all" ON public.admin_alerts;
CREATE POLICY "service_role_admin_alerts_all" 
  ON public.admin_alerts 
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

-- 4. Enable Supabase Realtime Publication for admin_alerts
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
