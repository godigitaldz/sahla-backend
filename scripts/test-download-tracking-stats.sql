-- Run after supabase/migrations/20261122120000_download_funnel_tracking.sql.
-- Uses only temporary fixtures inside a transaction and rolls them back.
BEGIN;

INSERT INTO public.download_events
  (created_at, event, session_id, platform, in_app, route, utm_source, utm_campaign, props, lang, is_bot)
VALUES
  ('2026-11-21T23:30:00Z', 'page_view', 'tracking-test-session-0001', 'ios', 'Instagram', '/open', 'instagram', 'fall', '{}', 'ar', false),
  ('2026-11-21T23:31:00Z', 'store_tap', 'tracking-test-session-0001', 'ios', 'Instagram', '/open', 'instagram', 'fall', '{"store":"appstore"}', 'ar', false),
  ('2026-11-21T23:32:00Z', 'page_view', 'tracking-test-session-0002', 'android', 'none', '/download', 'direct', null, '{}', 'ar', false),
  ('2026-11-21T23:33:00Z', 'app_open_attempt', 'tracking-test-session-0002', 'android', 'none', '/download', 'direct', null, '{"trigger":"auto"}', 'ar', false),
  ('2026-11-21T23:34:00Z', 'app_opened_likely', 'tracking-test-session-0002', 'android', 'none', '/download', 'direct', null, '{}', 'ar', false),
  ('2026-11-21T23:35:00Z', 'page_view', 'tracking-test-session-bot', 'desktop', 'none', '/open', 'crawler', null, '{}', 'en', true),
  ('2026-11-21T23:36:00Z', 'store_redirect', 'tracking-test-session-bot', 'desktop', 'none', '/open', 'crawler', null, '{"store":"appstore"}', 'en', true);

DO $$
DECLARE
  stats jsonb;
BEGIN
  stats := public.download_event_stats('2026-11-21', '2026-11-23', 'Africa/Algiers');
  IF stats #>> '{totals,entered}' <> '2' THEN RAISE EXCEPTION 'entered count mismatch: %', stats; END IF;
  IF stats #>> '{totals,reached_store}' <> '1' THEN RAISE EXCEPTION 'reached-store count mismatch: %', stats; END IF;
  IF stats #>> '{totals,app_open_attempts}' <> '1' THEN RAISE EXCEPTION 'app attempt count mismatch: %', stats; END IF;
  IF stats #>> '{totals,likely_opened}' <> '1' THEN RAISE EXCEPTION 'likely-opened count mismatch: %', stats; END IF;
  IF stats #>> '{totals,conversion_rate}' <> '50.00' THEN RAISE EXCEPTION 'conversion rate mismatch: %', stats; END IF;
  IF stats #>> '{totals,likely_opened_rate}' <> '50.00' THEN RAISE EXCEPTION 'likely-opened rate mismatch: %', stats; END IF;
  IF stats #>> '{byDay,0,day}' <> '2026-11-22' THEN RAISE EXCEPTION 'Algiers day bucket mismatch: %', stats; END IF;
  IF jsonb_array_length(stats->'byPlatform') <> 2 THEN RAISE EXCEPTION 'bot was not excluded from platform breakdown: %', stats; END IF;
END $$;

ROLLBACK;
