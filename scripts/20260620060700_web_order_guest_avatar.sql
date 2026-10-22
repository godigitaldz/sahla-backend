-- =============================================================================
-- WEB ORDER GUEST AVATAR (v607)
--
-- Restaurant partner cards read user_profiles.profile_image_url via customer join.
-- Stamp a unified avatar on web-only guest profiles (not real app users).
--
-- Default URL: https://pub-89a1a777d18d473592dcec45c880ebad.r2.dev/web.png
-- Override via system_config.web_order_guest_profile_image_url
--
-- Run after v606. Idempotent backfill on web guest profiles only.
-- =============================================================================

BEGIN;

-- ---------------------------------------------------------------------------
-- 1) Config + helpers
-- ---------------------------------------------------------------------------
INSERT INTO public.system_config (config_key, config_value, config_type, category, is_active, description)
VALUES (
  'web_order_guest_profile_image_url',
  '"https://pub-89a1a777d18d473592dcec45c880ebad.r2.dev/web.png"'::json,
  'string',
  'web_orders',
  true,
  'Public avatar URL for web checkout guest profiles on restaurant order cards'
)
ON CONFLICT (config_key) DO UPDATE SET
  config_value = EXCLUDED.config_value,
  config_type = EXCLUDED.config_type,
  category = EXCLUDED.category,
  is_active = EXCLUDED.is_active,
  description = EXCLUDED.description,
  updated_at = now();

CREATE OR REPLACE FUNCTION public.resolve_web_order_guest_profile_image_url()
RETURNS text
LANGUAGE sql
STABLE
SET search_path = public
AS $$
  SELECT coalesce(
    nullif(trim((
      SELECT sc.config_value #>> '{}'
      FROM public.system_config sc
      WHERE sc.config_key = 'web_order_guest_profile_image_url'
        AND sc.is_active = true
      LIMIT 1
    )), ''),
    'https://pub-89a1a777d18d473592dcec45c880ebad.r2.dev/web.png'
  );
$$;

CREATE OR REPLACE FUNCTION public.is_web_order_guest_profile(p_profile_id uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SET search_path = public, auth
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM auth.users u
    WHERE u.id = p_profile_id
      AND (
        coalesce(u.raw_user_meta_data->>'web_guest', '') IN ('true', '1', 't')
        OR coalesce(u.email, '') ILIKE '%@webguest.sahla.internal'
      )
  );
$$;

CREATE OR REPLACE FUNCTION public.stamp_web_order_guest_profile_image(p_profile_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_url text := public.resolve_web_order_guest_profile_image_url();
BEGIN
  IF p_profile_id IS NULL OR v_url = '' THEN
    RETURN;
  END IF;

  IF NOT public.is_web_order_guest_profile(p_profile_id) THEN
    RETURN;
  END IF;

  UPDATE public.user_profiles up
  SET
    profile_image_url = v_url,
    profile_image = v_url,
    updated_at = now()
  WHERE up.id = p_profile_id
    AND (
      coalesce(up.profile_image_url, '') IS DISTINCT FROM v_url
      OR coalesce(up.profile_image, '') IS DISTINCT FROM v_url
    );
END;
$$;

REVOKE ALL ON FUNCTION public.stamp_web_order_guest_profile_image(uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.stamp_web_order_guest_profile_image(uuid) TO service_role;

-- ---------------------------------------------------------------------------
-- 2) ensure_web_order_customer_id — stamp avatar on web guest profiles
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.ensure_web_order_customer_id(
  p_guest_phone text,
  p_guest_name text DEFAULT NULL
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth, extensions
AS $$
DECLARE
  v_phone text;
  v_id uuid;
  v_name text;
  v_email text;
  v_instance_id uuid;
  v_avatar text := public.resolve_web_order_guest_profile_image_url();
BEGIN
  v_phone := public.normalize_web_guest_phone(p_guest_phone);
  IF v_phone = '' THEN
    RETURN public.resolve_web_order_fallback_customer_id();
  END IF;

  v_name := nullif(trim(coalesce(p_guest_name, '')), '');
  IF v_name IS NULL THEN
    v_name := 'Web Guest';
  END IF;

  SELECT w.user_profile_id INTO v_id
  FROM public.web_order_guest_identity w
  WHERE w.phone_e164 = v_phone;

  IF v_id IS NOT NULL THEN
    PERFORM public.stamp_web_order_guest_profile_image(v_id);
    RETURN v_id;
  END IF;

  v_id := public.find_user_profile_id_by_phone(v_phone);
  IF v_id IS NOT NULL THEN
    INSERT INTO public.web_order_guest_identity (phone_e164, user_profile_id)
    VALUES (v_phone, v_id)
    ON CONFLICT (phone_e164) DO UPDATE
      SET user_profile_id = EXCLUDED.user_profile_id
    RETURNING user_profile_id INTO v_id;
    PERFORM public.stamp_web_order_guest_profile_image(v_id);
    RETURN v_id;
  END IF;

  v_id := gen_random_uuid();
  v_email := replace(v_id::text, '-', '') || '@webguest.sahla.internal';

  SELECT i.id INTO v_instance_id FROM auth.instances i LIMIT 1;
  IF v_instance_id IS NULL THEN
    v_instance_id := '00000000-0000-0000-0000-000000000000'::uuid;
  END IF;

  BEGIN
    INSERT INTO auth.users (
      instance_id,
      id,
      aud,
      role,
      email,
      encrypted_password,
      email_confirmed_at,
      phone,
      phone_confirmed_at,
      raw_app_meta_data,
      raw_user_meta_data,
      created_at,
      updated_at,
      is_anonymous
    ) VALUES (
      v_instance_id,
      v_id,
      'authenticated',
      'authenticated',
      v_email,
      extensions.crypt(gen_random_uuid()::text, extensions.gen_salt('bf')),
      now(),
      v_phone,
      now(),
      jsonb_build_object('provider', 'web_guest', 'providers', jsonb_build_array('web_guest')),
      jsonb_build_object('phone', v_phone, 'name', v_name, 'web_guest', true),
      now(),
      now(),
      true
    );
  EXCEPTION
    WHEN unique_violation THEN
      v_id := public.find_user_profile_id_by_phone(v_phone);
      IF v_id IS NOT NULL THEN
        INSERT INTO public.web_order_guest_identity (phone_e164, user_profile_id)
        VALUES (v_phone, v_id)
        ON CONFLICT (phone_e164) DO NOTHING;
        PERFORM public.stamp_web_order_guest_profile_image(v_id);
        RETURN v_id;
      END IF;
      RAISE;
  END;

  BEGIN
    INSERT INTO auth.identities (
      id,
      user_id,
      provider_id,
      identity_data,
      provider,
      last_sign_in_at,
      created_at,
      updated_at
    ) VALUES (
      gen_random_uuid(),
      v_id,
      v_id::text,
      jsonb_build_object('sub', v_id::text, 'phone', v_phone),
      'phone',
      now(),
      now(),
      now()
    );
  EXCEPTION
    WHEN undefined_column OR undefined_table THEN
      NULL;
    WHEN OTHERS THEN
      NULL;
  END;

  INSERT INTO public.user_profiles (
    id,
    role,
    is_verified,
    phone,
    name,
    profile_image_url,
    profile_image,
    language_preference,
    created_at,
    updated_at
  ) VALUES (
    v_id,
    'customer',
    true,
    v_phone,
    v_name,
    v_avatar,
    v_avatar,
    'ar',
    now(),
    now()
  )
  ON CONFLICT (id) DO UPDATE SET
    phone = EXCLUDED.phone,
    name = CASE
      WHEN trim(coalesce(public.user_profiles.name, '')) = '' THEN EXCLUDED.name
      ELSE public.user_profiles.name
    END,
    profile_image_url = EXCLUDED.profile_image_url,
    profile_image = EXCLUDED.profile_image,
    updated_at = now();

  INSERT INTO public.web_order_guest_identity (phone_e164, user_profile_id)
  VALUES (v_phone, v_id)
  ON CONFLICT (phone_e164) DO UPDATE
    SET user_profile_id = EXCLUDED.user_profile_id;

  RETURN v_id;
END;
$$;

REVOKE ALL ON FUNCTION public.ensure_web_order_customer_id(text, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.ensure_web_order_customer_id(text, text) TO service_role;

-- ---------------------------------------------------------------------------
-- 3) Backfill existing web guest profiles (skip real app users)
-- ---------------------------------------------------------------------------
DO $$
DECLARE
  r record;
BEGIN
  FOR r IN
    SELECT w.user_profile_id AS id
    FROM public.web_order_guest_identity w
  LOOP
    PERFORM public.stamp_web_order_guest_profile_image(r.id);
  END LOOP;
END $$;

COMMIT;

NOTIFY pgrst, 'reload schema';

-- =============================================================================
-- VERIFY
-- =============================================================================

-- V1) Config + resolver
-- SELECT public.resolve_web_order_guest_profile_image_url();

-- V2) W-000019 customer profile should have web.png
-- SELECT
--   o.public_order_code,
--   up.name,
--   up.profile_image_url,
--   public.is_web_order_guest_profile(up.id) AS is_web_guest
-- FROM orders o
-- JOIN user_profiles up ON up.id = o.customer_id
-- WHERE o.public_order_code = 'W-000019';

-- V3) Web guest map count with avatar
-- SELECT count(*) AS stamped
-- FROM web_order_guest_identity w
-- JOIN user_profiles up ON up.id = w.user_profile_id
-- WHERE up.profile_image_url = public.resolve_web_order_guest_profile_image_url();
