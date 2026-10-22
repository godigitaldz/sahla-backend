-- RB Melty: open 24h all week for web ordering tests (Africa/Algiers local hours).
-- Run in Supabase SQL Editor, then verify:
--   SELECT public.get_public_restaurant_by_slug('rb-melty') -> opening_hours;

DO $$
DECLARE
  v_day text;
  v_hours jsonb := '{}'::jsonb;
BEGIN
  FOREACH v_day IN ARRAY ARRAY[
    'monday','tuesday','wednesday','thursday','friday','saturday','sunday'
  ] LOOP
    v_hours := v_hours || jsonb_build_object(
      v_day,
      jsonb_build_object(
        'open', '00:00',
        'close', '23:59',
        'isOpen', true,
        'breakEnabled', false,
        'hasBreak', false
      )
    );
  END LOOP;

  UPDATE public.restaurants
  SET
    is_open = true,
    opening_hours = v_hours,
    closing_hours = v_hours,
    updated_at = now()
  WHERE public_slug = 'rb-melty';
END $$;

SELECT id, name, is_open, opening_hours->'saturday' AS saturday_hours
FROM public.restaurants
WHERE public_slug = 'rb-melty';
