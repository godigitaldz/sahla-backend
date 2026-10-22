-- Repair invalid web_order_fallback_customer_id (e.g. literal "YOUR-USER-UUID").
-- Safe to re-run. Uses manual_order_fallback_customer_id as source of truth.

BEGIN;

-- Replace invalid or empty web fallback with manual fallback UUID.
UPDATE public.system_config w
SET
  config_value = m.config_value,
  is_active = true,
  updated_at = now()
FROM public.system_config m
WHERE w.config_key = 'web_order_fallback_customer_id'
  AND m.config_key = 'manual_order_fallback_customer_id'
  AND m.is_active = true
  AND trim(coalesce(m.config_value #>> '{}', '')) ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
  AND (
    coalesce(nullif(trim(w.config_value #>> '{}'), ''), '') = ''
    OR coalesce(nullif(trim(w.config_value #>> '{}'), ''), '') !~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
  );

-- Create web row from manual when missing.
INSERT INTO public.system_config (config_key, config_value, config_type, category, is_active, description)
SELECT
  'web_order_fallback_customer_id',
  m.config_value,
  'string',
  'web_orders',
  true,
  'Fallback user_profiles.id for guest web orders'
FROM public.system_config m
WHERE m.config_key = 'manual_order_fallback_customer_id'
  AND m.is_active = true
  AND trim(coalesce(m.config_value #>> '{}', '')) ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
  AND NOT EXISTS (
    SELECT 1 FROM public.system_config w WHERE w.config_key = 'web_order_fallback_customer_id'
  );

CREATE OR REPLACE FUNCTION public.resolve_web_order_customer_id(p_guest_phone text)
RETURNS uuid
LANGUAGE plpgsql
STABLE
SET search_path = public
AS $$
DECLARE
  v_phone text := trim(coalesce(p_guest_phone, ''));
  v_id uuid;
  v_fallback text;
  v_local text;
  v_digits text;
BEGIN
  IF v_phone <> '' THEN
    v_local := v_phone;
    IF v_local LIKE '+213%' THEN
      v_local := '0' || substr(v_local, 5);
    END IF;
    v_digits := regexp_replace(v_phone, '\D', '', 'g');
    IF v_digits LIKE '213%' AND length(v_digits) >= 12 THEN
      v_digits := substr(v_digits, 4);
    ELSIF v_digits LIKE '0%' THEN
      v_digits := substr(v_digits, 2);
    END IF;

    SELECT up.id INTO v_id
    FROM public.user_profiles up
    WHERE up.phone IS NOT NULL
      AND trim(up.phone) <> ''
      AND (
        trim(up.phone) = v_phone
        OR trim(up.phone) = v_local
        OR regexp_replace(trim(up.phone), '\D', '', 'g') = regexp_replace(v_phone, '\D', '', 'g')
        OR regexp_replace(trim(up.phone), '\D', '', 'g') = v_digits
        OR trim(up.phone) = ('+213' || v_digits)
        OR trim(up.phone) = ('0' || v_digits)
      )
    LIMIT 1;

    IF v_id IS NOT NULL THEN
      RETURN v_id;
    END IF;
  END IF;

  SELECT coalesce(
    nullif(trim((
      SELECT w.config_value #>> '{}'
      FROM public.system_config w
      WHERE w.config_key = 'web_order_fallback_customer_id'
        AND w.is_active = true
      LIMIT 1
    )), ''),
    nullif(trim((
      SELECT m.config_value #>> '{}'
      FROM public.system_config m
      WHERE m.config_key = 'manual_order_fallback_customer_id'
        AND m.is_active = true
      LIMIT 1
    )), '')
  )
  INTO v_fallback;

  IF v_fallback IS NULL OR v_fallback = '' THEN
    RETURN NULL;
  END IF;

  IF v_fallback !~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' THEN
    RETURN NULL;
  END IF;

  SELECT up.id INTO v_id
  FROM public.user_profiles up
  WHERE up.id = v_fallback::uuid
  LIMIT 1;

  RETURN v_id;
END;
$$;

GRANT EXECUTE ON FUNCTION public.resolve_web_order_customer_id(text) TO service_role;

COMMIT;

-- Verify (must return 68b1a9f1-084c-4c2d-bb6e-4f12987d3ab4, not NULL):
SELECT config_key, config_value #>> '{}' AS fallback_id
FROM public.system_config
WHERE config_key IN ('web_order_fallback_customer_id', 'manual_order_fallback_customer_id');

SELECT public.resolve_web_order_customer_id('+213555000000') AS unknown_phone_fallback;
