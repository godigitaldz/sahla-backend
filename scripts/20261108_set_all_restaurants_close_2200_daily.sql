-- Force every restaurant schedule day to close at 22:00 (Africa/Algiers).
-- Preserves open times, breaks, and isOpen flags. Updates all hours columns.
-- Reversible by restoring prior opening_hours from backups / partner edits.

BEGIN;

CREATE OR REPLACE FUNCTION public._jsonb_set_all_day_close(
  p_hours jsonb,
  p_close text
)
RETURNS jsonb
LANGUAGE sql
IMMUTABLE
AS $$
  SELECT CASE
    WHEN p_hours IS NULL OR jsonb_typeof(p_hours) <> 'object' THEN p_hours
    ELSE (
      SELECT coalesce(
        jsonb_object_agg(
          e.key,
          CASE
            WHEN jsonb_typeof(e.value) = 'object'
              THEN e.value || jsonb_build_object('close', p_close)
            ELSE e.value
          END
        ),
        '{}'::jsonb
      )
      FROM jsonb_each(p_hours) AS e(key, value)
    )
  END;
$$;

UPDATE public.restaurants r
SET
  opening_hours = CASE
    WHEN r.is_open THEN public._jsonb_set_all_day_close(
      coalesce(r.opening_hours, r.opening_hours_backup),
      '22:00'
    )
    ELSE NULL
  END,
  closing_hours = CASE
    WHEN r.is_open THEN public._jsonb_set_all_day_close(
      coalesce(r.closing_hours, r.closing_hours_backup, r.opening_hours, r.opening_hours_backup),
      '22:00'
    )
    ELSE NULL
  END,
  opening_hours_backup = public._jsonb_set_all_day_close(
    coalesce(r.opening_hours_backup, r.opening_hours),
    '22:00'
  ),
  closing_hours_backup = public._jsonb_set_all_day_close(
    coalesce(r.closing_hours_backup, r.closing_hours, r.opening_hours_backup, r.opening_hours),
    '22:00'
  ),
  business_timezone = coalesce(nullif(trim(r.business_timezone), ''), 'Africa/Algiers'),
  updated_at = timezone('utc', now())
WHERE coalesce(r.opening_hours, r.opening_hours_backup, r.closing_hours, r.closing_hours_backup)
  IS NOT NULL;

DROP FUNCTION IF EXISTS public._jsonb_set_all_day_close(jsonb, text);

NOTIFY pgrst, 'reload schema';

COMMIT;
