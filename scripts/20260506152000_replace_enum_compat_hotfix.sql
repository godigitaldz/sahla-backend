-- Hotfix: compatibility overload for replace() on promo_code_applies_to_enum.
-- Fixes errors like:
--   function replace(promo_code_applies_to_enum, unknown, unknown) does not exist (42883)
-- Safe to run multiple times.

DO $$
BEGIN
  IF EXISTS (
    SELECT 1
    FROM pg_type t
    JOIN pg_namespace n ON n.oid = t.typnamespace
    WHERE n.nspname = 'public'
      AND t.typname = 'promo_code_applies_to_enum'
  ) THEN
    EXECUTE $fn$
      CREATE OR REPLACE FUNCTION public.replace(
        p_value public.promo_code_applies_to_enum,
        p_from text,
        p_to text
      )
      RETURNS text
      LANGUAGE sql
      IMMUTABLE
      PARALLEL SAFE
      AS $body$
        SELECT pg_catalog.replace(p_value::text, p_from, p_to);
      $body$;
    $fn$;
  END IF;
END;
$$;

