-- Performance dashboard: persist per-courier admin notes (user_id → text) in system_config.
-- Notes are merged atomically so concurrent saves for different couriers do not clobber each other.
-- Verification:
--   select config_key, config_value from public.system_config
--   where config_key = 'performance_dashboard_delivery_man_notes';
--   select public.upsert_performance_delivery_man_note(
--     '00000000-0000-0000-0000-000000000001'::uuid,
--     'test note'
--   );

INSERT INTO public.system_config (config_key, config_value, config_type, category, is_active, description)
VALUES (
  'performance_dashboard_delivery_man_notes',
  '{}'::jsonb,
  'object',
  'performance_dashboard',
  true,
  'Admin notes keyed by delivery courier user_id for performance dashboard Delivery man tab'
)
ON CONFLICT (config_key) DO NOTHING;

CREATE OR REPLACE FUNCTION public.upsert_performance_delivery_man_note(
  p_user_id uuid,
  p_note text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_key text := 'performance_dashboard_delivery_man_notes';
  v_user_key text := p_user_id::text;
  v_note text := left(btrim(coalesce(p_note, '')), 2000);
  v_notes jsonb;
BEGIN
  IF p_user_id IS NULL THEN
    RAISE EXCEPTION 'user_id is required';
  END IF;

  INSERT INTO public.system_config (config_key, config_value, config_type, category, is_active, description)
  VALUES (
    v_key,
    '{}'::jsonb,
    'object',
    'performance_dashboard',
    true,
    'Admin notes keyed by delivery courier user_id for performance dashboard Delivery man tab'
  )
  ON CONFLICT (config_key) DO NOTHING;

  IF v_note = '' THEN
    UPDATE public.system_config
    SET config_value = coalesce(config_value, '{}'::jsonb) - v_user_key,
        updated_at = now()
    WHERE config_key = v_key
    RETURNING config_value INTO v_notes;
  ELSE
    UPDATE public.system_config
    SET config_value = coalesce(config_value, '{}'::jsonb) || jsonb_build_object(v_user_key, to_jsonb(v_note)),
        updated_at = now()
    WHERE config_key = v_key
    RETURNING config_value INTO v_notes;
  END IF;

  RETURN jsonb_build_object(
    'user_id', v_user_key,
    'note', coalesce(v_notes ->> v_user_key, ''),
    'notes', coalesce(v_notes, '{}'::jsonb)
  );
END;
$$;

REVOKE ALL ON FUNCTION public.upsert_performance_delivery_man_note(uuid, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.upsert_performance_delivery_man_note(uuid, text) TO service_role;
