-- =============================================================================
-- TABLE ORDERING — schema, constraints, venue rotation, session exchange
-- Feature flag: restaurants.table_ordering_enabled (default false)
-- Idempotent; safe to re-run.
-- =============================================================================

BEGIN;

CREATE EXTENSION IF NOT EXISTS pgcrypto WITH SCHEMA extensions;

-- digest() lives in extensions (Supabase); first argument must be bytea.
-- ---------------------------------------------------------------------------
-- Feature flag
-- ---------------------------------------------------------------------------
ALTER TABLE public.restaurants
  ADD COLUMN IF NOT EXISTS table_ordering_enabled boolean NOT NULL DEFAULT false;

-- ---------------------------------------------------------------------------
-- restaurant_tables
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.restaurant_tables (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  restaurant_id uuid NOT NULL REFERENCES public.restaurants(id) ON DELETE RESTRICT,
  table_number text NOT NULL,
  table_label text,
  sort_order int NOT NULL DEFAULT 0,
  is_active boolean NOT NULL DEFAULT true,
  deleted_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT restaurant_tables_table_number_len_chk
    CHECK (char_length(trim(table_number)) BETWEEN 1 AND 32)
);

CREATE INDEX IF NOT EXISTS restaurant_tables_restaurant_active_idx
  ON public.restaurant_tables (restaurant_id)
  WHERE deleted_at IS NULL AND is_active = true;

CREATE UNIQUE INDEX IF NOT EXISTS restaurant_tables_restaurant_number_uidx
  ON public.restaurant_tables (restaurant_id, lower(trim(table_number)))
  WHERE deleted_at IS NULL;

-- ---------------------------------------------------------------------------
-- restaurant_table_codes (hashed opaque QR secret)
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.restaurant_table_codes (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  restaurant_table_id uuid NOT NULL REFERENCES public.restaurant_tables(id) ON DELETE RESTRICT,
  code_hash bytea NOT NULL,
  code_token uuid,
  version int NOT NULL DEFAULT 1,
  is_active boolean NOT NULL DEFAULT true,
  revoked_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  created_by uuid REFERENCES public.user_profiles(id) ON DELETE SET NULL,
  CONSTRAINT restaurant_table_codes_version_positive_chk CHECK (version > 0)
);

CREATE UNIQUE INDEX IF NOT EXISTS restaurant_table_codes_one_active_per_table_uidx
  ON public.restaurant_table_codes (restaurant_table_id)
  WHERE is_active = true AND revoked_at IS NULL;

CREATE UNIQUE INDEX IF NOT EXISTS restaurant_table_codes_hash_uidx
  ON public.restaurant_table_codes (code_hash)
  WHERE is_active = true AND revoked_at IS NULL;

-- ---------------------------------------------------------------------------
-- restaurant_venue_code_windows (rotating in-restaurant presence code)
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.restaurant_venue_code_windows (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  restaurant_id uuid NOT NULL REFERENCES public.restaurants(id) ON DELETE RESTRICT,
  code_hash bytea NOT NULL,
  window_start timestamptz NOT NULL,
  window_end timestamptz NOT NULL,
  version int NOT NULL DEFAULT 1,
  created_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT restaurant_venue_code_windows_window_chk CHECK (window_end > window_start),
  CONSTRAINT restaurant_venue_code_windows_version_positive_chk CHECK (version > 0)
);

CREATE INDEX IF NOT EXISTS restaurant_venue_code_windows_lookup_idx
  ON public.restaurant_venue_code_windows (restaurant_id, window_end DESC);

-- ---------------------------------------------------------------------------
-- table_order_sessions
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.table_order_sessions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  restaurant_table_id uuid NOT NULL REFERENCES public.restaurant_tables(id) ON DELETE RESTRICT,
  table_code_id uuid NOT NULL REFERENCES public.restaurant_table_codes(id) ON DELETE RESTRICT,
  venue_window_id uuid REFERENCES public.restaurant_venue_code_windows(id) ON DELETE RESTRICT,
  session_token_hash bytea NOT NULL,
  expires_at timestamptz NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  consumed_at timestamptz,
  last_activity_at timestamptz NOT NULL DEFAULT now(),
  revoked_at timestamptz,
  device_binding_hash bytea,
  CONSTRAINT table_order_sessions_expires_after_created_chk CHECK (expires_at > created_at),
  CONSTRAINT table_order_sessions_consumed_after_created_chk
    CHECK (consumed_at IS NULL OR consumed_at >= created_at)
);

CREATE UNIQUE INDEX IF NOT EXISTS table_order_sessions_token_hash_uidx
  ON public.table_order_sessions (session_token_hash);

CREATE INDEX IF NOT EXISTS table_order_sessions_expires_idx
  ON public.table_order_sessions (expires_at)
  WHERE revoked_at IS NULL;

CREATE INDEX IF NOT EXISTS table_order_sessions_table_active_idx
  ON public.table_order_sessions (restaurant_table_id, created_at DESC)
  WHERE revoked_at IS NULL;

-- ---------------------------------------------------------------------------
-- admin_table_audit_log
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.admin_table_audit_log (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  admin_user_id uuid NOT NULL REFERENCES public.user_profiles(id) ON DELETE RESTRICT,
  action text NOT NULL,
  restaurant_id uuid REFERENCES public.restaurants(id) ON DELETE SET NULL,
  restaurant_table_id uuid REFERENCES public.restaurant_tables(id) ON DELETE SET NULL,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS admin_table_audit_log_created_idx
  ON public.admin_table_audit_log (created_at DESC);

-- ---------------------------------------------------------------------------
-- orders extensions
-- ---------------------------------------------------------------------------
ALTER TABLE public.orders
  ADD COLUMN IF NOT EXISTS table_id uuid REFERENCES public.restaurant_tables(id) ON DELETE RESTRICT,
  ADD COLUMN IF NOT EXISTS table_session_id uuid REFERENCES public.table_order_sessions(id) ON DELETE RESTRICT;

-- Fulfillment + table invariants
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'orders_table_fulfillment_identity_chk'
  ) THEN
    ALTER TABLE public.orders
      ADD CONSTRAINT orders_table_fulfillment_identity_chk
      CHECK (
        (fulfillment_type = 'table' AND table_id IS NOT NULL AND table_session_id IS NOT NULL)
        OR (fulfillment_type IS DISTINCT FROM 'table' AND table_id IS NULL AND table_session_id IS NULL)
      );
  END IF;
END $$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'orders_table_zero_delivery_chk'
  ) THEN
    ALTER TABLE public.orders
      ADD CONSTRAINT orders_table_zero_delivery_chk
      CHECK (
        fulfillment_type IS DISTINCT FROM 'table'
        OR (
          coalesce(delivery_fee, 0) = 0
          AND coalesce(original_delivery_fee, 0) = 0
          AND coalesce(delivery_tax, 0) = 0
          AND coalesce(net_delivery_amount, 0) = 0
          AND delivery_person_id IS NULL
        )
      );
  END IF;
END $$;

CREATE INDEX IF NOT EXISTS orders_table_id_created_idx
  ON public.orders (table_id, created_at DESC)
  WHERE table_id IS NOT NULL;

-- ---------------------------------------------------------------------------
-- Hash helpers
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.sha256_bytea(p_input text)
RETURNS bytea
LANGUAGE sql
IMMUTABLE
SET search_path = public, extensions
AS $$
  SELECT extensions.digest(convert_to(coalesce(p_input, ''), 'UTF8'), 'sha256');
$$;

-- ---------------------------------------------------------------------------
-- Table order card tag (partner app)
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.format_table_order_card_special_instructions(
  p_table_number text,
  p_public_order_code text,
  p_customer_notes text DEFAULT NULL
)
RETURNS text
LANGUAGE plpgsql
IMMUTABLE
SET search_path = public
AS $$
DECLARE
  v_table text := nullif(trim(coalesce(p_table_number, '')), '');
  v_code text := nullif(trim(coalesce(p_public_order_code, '')), '');
  v_tag text;
  v_notes text := nullif(trim(coalesce(p_customer_notes, '')), '');
BEGIN
  v_tag := 'طلب طاولة (' || coalesce(v_table, '?') || ') — ' || coalesce(v_code, 'T');

  IF v_notes IS NULL THEN
    RETURN v_tag;
  END IF;

  RETURN v_tag || E'\n' || v_notes;
END;
$$;

-- ---------------------------------------------------------------------------
-- Rotate venue codes (pg_cron: every 5 min)
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.rotate_restaurant_venue_codes()
RETURNS int
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_restaurant record;
  v_code text;
  v_count int := 0;
  v_now timestamptz := now();
  v_window_end timestamptz := v_now + interval '5 minutes';
BEGIN
  FOR v_restaurant IN
    SELECT r.id
    FROM public.restaurants r
    WHERE r.table_ordering_enabled = true
      AND r.is_verified = true
  LOOP
    v_code := lpad((floor(random() * 1000000))::int::text, 6, '0');

    INSERT INTO public.restaurant_venue_code_windows (
      restaurant_id,
      code_hash,
      window_start,
      window_end,
      version
    ) VALUES (
      v_restaurant.id,
      public.sha256_bytea(v_code),
      v_now,
      v_window_end,
      coalesce(
        (SELECT max(w.version) + 1 FROM public.restaurant_venue_code_windows w WHERE w.restaurant_id = v_restaurant.id),
        1
      )
    );

    v_count := v_count + 1;
  END LOOP;

  RETURN v_count;
END;
$$;

REVOKE ALL ON FUNCTION public.rotate_restaurant_venue_codes() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.rotate_restaurant_venue_codes() TO service_role;

-- ---------------------------------------------------------------------------
-- Exchange table presence: validate QR + venue code, mint session
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.exchange_table_presence(
  p_table_code text,
  p_venue_code text,
  p_session_token_hash bytea,
  p_device_binding_hash bytea DEFAULT NULL,
  p_session_ttl_minutes int DEFAULT 30
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_code_hash bytea;
  v_venue_hash bytea;
  v_table_code record;
  v_venue_window record;
  v_session_id uuid;
  v_now timestamptz := now();
  v_expires timestamptz;
BEGIN
  IF nullif(trim(coalesce(p_table_code, '')), '') IS NULL THEN
    RAISE EXCEPTION 'table_code_required';
  END IF;

  IF nullif(trim(coalesce(p_venue_code, '')), '') IS NULL THEN
    RAISE EXCEPTION 'venue_code_required';
  END IF;

  IF p_session_token_hash IS NULL THEN
    RAISE EXCEPTION 'session_token_required';
  END IF;

  v_code_hash := public.sha256_bytea(trim(p_table_code));
  v_venue_hash := public.sha256_bytea(trim(p_venue_code));

  SELECT
    tc.id AS code_id,
    tc.restaurant_table_id,
    rt.restaurant_id,
    rt.table_number,
    rt.table_label,
    rt.is_active AS table_active,
    r.public_slug,
    r.name AS restaurant_name,
    r.table_ordering_enabled,
    r.is_public_web_enabled,
    r.is_verified
  INTO v_table_code
  FROM public.restaurant_table_codes tc
  JOIN public.restaurant_tables rt ON rt.id = tc.restaurant_table_id
  JOIN public.restaurants r ON r.id = rt.restaurant_id
  WHERE tc.code_hash = v_code_hash
    AND tc.is_active = true
    AND tc.revoked_at IS NULL
    AND rt.deleted_at IS NULL
  LIMIT 1
  FOR UPDATE OF tc;

  IF v_table_code.code_id IS NULL THEN
    RAISE EXCEPTION 'invalid_table_code';
  END IF;

  IF NOT v_table_code.table_ordering_enabled THEN
    RAISE EXCEPTION 'table_ordering_disabled';
  END IF;

  IF NOT v_table_code.is_verified OR NOT v_table_code.is_public_web_enabled THEN
    RAISE EXCEPTION 'restaurant_not_available';
  END IF;

  IF NOT v_table_code.table_active THEN
    RAISE EXCEPTION 'table_inactive';
  END IF;

  SELECT w.id, w.window_end
  INTO v_venue_window
  FROM public.restaurant_venue_code_windows w
  WHERE w.restaurant_id = v_table_code.restaurant_id
    AND w.code_hash = v_venue_hash
    AND w.window_start <= v_now
    AND w.window_end > v_now
  ORDER BY w.window_end DESC
  LIMIT 1;

  IF v_venue_window.id IS NULL THEN
    RAISE EXCEPTION 'invalid_venue_code';
  END IF;

  -- Revoke prior active sessions for same table + device binding
  IF p_device_binding_hash IS NOT NULL THEN
    UPDATE public.table_order_sessions s
    SET revoked_at = v_now
    WHERE s.restaurant_table_id = v_table_code.restaurant_table_id
      AND s.device_binding_hash = p_device_binding_hash
      AND s.revoked_at IS NULL
      AND s.expires_at > v_now;
  END IF;

  v_expires := v_now + make_interval(mins => greatest(p_session_ttl_minutes, 5));

  INSERT INTO public.table_order_sessions (
    restaurant_table_id,
    table_code_id,
    venue_window_id,
    session_token_hash,
    expires_at,
    device_binding_hash
  ) VALUES (
    v_table_code.restaurant_table_id,
    v_table_code.code_id,
    v_venue_window.id,
    p_session_token_hash,
    v_expires,
    p_device_binding_hash
  )
  RETURNING id INTO v_session_id;

  RETURN jsonb_build_object(
    'session_id', v_session_id,
    'expires_at', v_expires,
    'restaurant_slug', v_table_code.public_slug,
    'restaurant_name', v_table_code.restaurant_name,
    'table_number', v_table_code.table_number,
    'table_label', v_table_code.table_label,
    'restaurant_table_id', v_table_code.restaurant_table_id
  );
END;
$$;

REVOKE ALL ON FUNCTION public.exchange_table_presence(text, text, bytea, bytea, int) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.exchange_table_presence(text, text, bytea, bytea, int) TO service_role;

-- ---------------------------------------------------------------------------
-- Session lookup (service role only)
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.get_table_session_context(p_session_token_hash bytea)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_now timestamptz := now();
  v_row record;
BEGIN
  SELECT
    s.id AS session_id,
    s.expires_at,
    s.revoked_at,
    rt.id AS restaurant_table_id,
    rt.table_number,
    rt.table_label,
    r.id AS restaurant_id,
    r.public_slug,
    r.name AS restaurant_name,
    r.table_ordering_enabled,
    r.is_open,
    r.opening_hours,
    r.closing_hours,
    r.vacation_starts_at,
    r.vacation_returns_at
  INTO v_row
  FROM public.table_order_sessions s
  JOIN public.restaurant_tables rt ON rt.id = s.restaurant_table_id
  JOIN public.restaurants r ON r.id = rt.restaurant_id
  WHERE s.session_token_hash = p_session_token_hash
  LIMIT 1;

  IF v_row.session_id IS NULL THEN
    RETURN NULL;
  END IF;

  IF v_row.revoked_at IS NOT NULL OR v_row.expires_at <= v_now OR NOT v_row.table_ordering_enabled THEN
    RETURN jsonb_build_object('status', 'expired');
  END IF;

  RETURN jsonb_build_object(
    'status', 'active',
    'session_id', v_row.session_id,
    'expires_at', v_row.expires_at,
    'restaurant_slug', v_row.public_slug,
    'restaurant_name', v_row.restaurant_name,
    'table_number', v_row.table_number,
    'table_label', v_row.table_label,
    'restaurant_table_id', v_row.restaurant_table_id,
    'restaurant_id', v_row.restaurant_id
  );
END;
$$;

REVOKE ALL ON FUNCTION public.get_table_session_context(bytea) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_table_session_context(bytea) TO service_role;

-- ---------------------------------------------------------------------------
-- Immutability: fulfillment/table identity after insert
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.trg_orders_immutable_table_identity()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = public
AS $$
BEGIN
  IF TG_OP = 'UPDATE' THEN
    IF NEW.fulfillment_type IS DISTINCT FROM OLD.fulfillment_type THEN
      RAISE EXCEPTION 'fulfillment_type_immutable';
    END IF;
    IF NEW.table_id IS DISTINCT FROM OLD.table_id THEN
      RAISE EXCEPTION 'table_id_immutable';
    END IF;
    IF NEW.table_session_id IS DISTINCT FROM OLD.table_session_id THEN
      RAISE EXCEPTION 'table_session_id_immutable';
    END IF;
    IF NEW.restaurant_id IS DISTINCT FROM OLD.restaurant_id THEN
      RAISE EXCEPTION 'restaurant_id_immutable';
    END IF;
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_orders_immutable_table_identity ON public.orders;
CREATE TRIGGER trg_orders_immutable_table_identity
  BEFORE UPDATE ON public.orders
  FOR EACH ROW
  EXECUTE FUNCTION public.trg_orders_immutable_table_identity();

-- ---------------------------------------------------------------------------
-- Dispatch guard: non-delivery never dispatches
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.trg_orders_non_delivery_no_dispatch()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = public
AS $$
BEGIN
  IF NEW.fulfillment_type IS DISTINCT FROM 'delivery' THEN
    NEW.dispatch_active := false;
    NEW.dispatch_next_run_at := NULL;
    NEW.dispatch_attempt := coalesce(NEW.dispatch_attempt, 0);
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_orders_non_delivery_no_dispatch ON public.orders;
CREATE TRIGGER trg_orders_non_delivery_no_dispatch
  BEFORE INSERT OR UPDATE OF fulfillment_type, dispatch_active, dispatch_next_run_at
  ON public.orders
  FOR EACH ROW
  EXECUTE FUNCTION public.trg_orders_non_delivery_no_dispatch();

-- ---------------------------------------------------------------------------
-- RLS (deny anon/authenticated direct access to secrets)
-- ---------------------------------------------------------------------------
ALTER TABLE public.restaurant_tables ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.restaurant_table_codes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.restaurant_venue_code_windows ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.table_order_sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.admin_table_audit_log ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS restaurant_tables_service_role ON public.restaurant_tables;
CREATE POLICY restaurant_tables_service_role ON public.restaurant_tables
  FOR ALL TO service_role USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS restaurant_table_codes_service_role ON public.restaurant_table_codes;
CREATE POLICY restaurant_table_codes_service_role ON public.restaurant_table_codes
  FOR ALL TO service_role USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS restaurant_venue_code_windows_service_role ON public.restaurant_venue_code_windows;
CREATE POLICY restaurant_venue_code_windows_service_role ON public.restaurant_venue_code_windows
  FOR ALL TO service_role USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS table_order_sessions_service_role ON public.table_order_sessions;
CREATE POLICY table_order_sessions_service_role ON public.table_order_sessions
  FOR ALL TO service_role USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS admin_table_audit_log_service_role ON public.admin_table_audit_log;
CREATE POLICY admin_table_audit_log_service_role ON public.admin_table_audit_log
  FOR ALL TO service_role USING (true) WITH CHECK (true);

-- Restaurant staff read own tables (no codes)
DROP POLICY IF EXISTS restaurant_tables_staff_select ON public.restaurant_tables;
CREATE POLICY restaurant_tables_staff_select ON public.restaurant_tables
  FOR SELECT TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.restaurant_staff_members rsm
      WHERE rsm.restaurant_id = restaurant_tables.restaurant_id
        AND rsm.user_id = auth.uid()
        AND rsm.status = 'active'
    )
  );

COMMIT;

NOTIFY pgrst, 'reload schema';

-- Verification:
-- select to_regclass('public.restaurant_tables');
-- select conname from pg_constraint where conrelid = 'public.orders'::regclass and conname ilike '%table%';
