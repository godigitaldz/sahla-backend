BEGIN;

CREATE TABLE IF NOT EXISTS public.download_events (
  id bigserial PRIMARY KEY,
  created_at timestamptz NOT NULL DEFAULT now(),
  event text NOT NULL,
  session_id text NOT NULL,
  platform text,
  in_app text,
  route text,
  utm_source text,
  utm_medium text,
  utm_campaign text,
  ref text,
  props jsonb NOT NULL DEFAULT '{}'::jsonb,
  build text,
  lang text,
  is_bot boolean NOT NULL DEFAULT false,
  country text,
  ua_hash text
);

CREATE INDEX IF NOT EXISTS idx_download_events_created_at ON public.download_events (created_at);
CREATE INDEX IF NOT EXISTS idx_download_events_event_created_at ON public.download_events (event, created_at);
CREATE INDEX IF NOT EXISTS idx_download_events_session_id ON public.download_events (session_id);
CREATE UNIQUE INDEX IF NOT EXISTS idx_download_events_page_view_session
  ON public.download_events (session_id) WHERE event = 'page_view';

ALTER TABLE public.download_events ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE public.download_events FROM PUBLIC, anon, authenticated;
GRANT SELECT, INSERT ON TABLE public.download_events TO service_role;
GRANT USAGE, SELECT ON SEQUENCE public.download_events_id_seq TO service_role;

CREATE OR REPLACE FUNCTION public.download_event_stats(
  p_from date,
  p_to date,
  p_tz text DEFAULT 'Africa/Algiers'
)
RETURNS jsonb
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
WITH filtered AS (
  SELECT * FROM public.download_events
  WHERE created_at >= (p_from::timestamp AT TIME ZONE p_tz)
    AND created_at < (p_to::timestamp AT TIME ZONE p_tz)
    AND is_bot = false
),
sessions AS (
  SELECT session_id,
    (array_agg(platform ORDER BY created_at) FILTER (WHERE platform IS NOT NULL))[1] AS platform,
    (array_agg(in_app ORDER BY created_at) FILTER (WHERE in_app IS NOT NULL))[1] AS in_app,
    (array_agg(route ORDER BY created_at) FILTER (WHERE route IS NOT NULL))[1] AS route,
    (array_agg(COALESCE(NULLIF(utm_source, ''), NULLIF(ref, ''), 'direct') ORDER BY created_at))[1] AS source,
    (array_agg(NULLIF(utm_campaign, '') ORDER BY created_at) FILTER (WHERE NULLIF(utm_campaign, '') IS NOT NULL))[1] AS campaign,
    min(created_at) FILTER (WHERE event = 'page_view') AS entered_at,
    bool_or(event IN ('store_redirect', 'store_tap')) AS reached_store,
    bool_or(event = 'app_open_attempt') AS attempted_open,
    bool_or(event = 'app_opened_likely') AS likely_opened,
    bool_or(event = 'copy_link') AS copied_link,
    bool_or(event = 'escape_tap') AS escaped,
    bool_or(event = 'retry_tap') AS retried
  FROM filtered GROUP BY session_id
),
totals AS (
  SELECT
    count(*) FILTER (WHERE entered_at IS NOT NULL) AS entered,
    count(*) FILTER (WHERE reached_store) AS reached_store,
    count(*) FILTER (WHERE attempted_open) AS app_open_attempts,
    count(*) FILTER (WHERE likely_opened) AS likely_opened,
    count(*) FILTER (WHERE copied_link) AS copy_link,
    count(*) FILTER (WHERE escaped) AS escape_tap,
    count(*) FILTER (WHERE retried) AS retry
  FROM sessions
),
by_day AS (
  SELECT (entered_at AT TIME ZONE p_tz)::date AS day, count(*) AS entered,
    count(*) FILTER (WHERE reached_store) AS reached_store,
    count(*) FILTER (WHERE attempted_open) AS app_open_attempts,
    count(*) FILTER (WHERE likely_opened) AS likely_opened
  FROM sessions WHERE entered_at IS NOT NULL GROUP BY 1
),
by_source AS (
  SELECT source, campaign, count(*) AS sessions FROM sessions
  WHERE entered_at IS NOT NULL GROUP BY source, campaign
),
ranked_source AS (
  SELECT *, row_number() OVER (ORDER BY sessions DESC, source, campaign NULLS FIRST) AS rank
  FROM by_source
),
source_rows AS (
  SELECT
    COALESCE((SELECT jsonb_agg(jsonb_build_object(
      'source', source, 'campaign', campaign, 'sessions', sessions
    ) ORDER BY rank) FROM ranked_source WHERE rank <= 10), '[]'::jsonb)
    || COALESCE((SELECT CASE WHEN count(*) = 0 THEN '[]'::jsonb ELSE
      jsonb_build_array(jsonb_build_object('source', 'other', 'campaign', NULL, 'sessions', sum(sessions)))
    END FROM ranked_source WHERE rank > 10), '[]'::jsonb) AS rows
),
platform_rows AS (
  SELECT jsonb_agg(jsonb_build_object('key', platform, 'sessions', n) ORDER BY n DESC) AS rows
  FROM (SELECT platform, count(*) n FROM sessions WHERE entered_at IS NOT NULL GROUP BY platform) q
),
inapp_rows AS (
  SELECT jsonb_agg(jsonb_build_object('key', in_app, 'sessions', n) ORDER BY n DESC) AS rows
  FROM (SELECT in_app, count(*) n FROM sessions WHERE entered_at IS NOT NULL GROUP BY in_app) q
),
route_rows AS (
  SELECT jsonb_agg(jsonb_build_object('key', route, 'sessions', n) ORDER BY n DESC) AS rows
  FROM (SELECT route, count(*) n FROM sessions WHERE entered_at IS NOT NULL GROUP BY route) q
),
day_rows AS (
  SELECT jsonb_agg(jsonb_build_object('day', day, 'entered', entered,
    'reached_store', reached_store, 'app_open_attempts', app_open_attempts,
    'likely_opened', likely_opened) ORDER BY day) AS rows FROM by_day
)
SELECT jsonb_build_object(
  'totals', (SELECT to_jsonb(t) || jsonb_build_object(
    'conversion_rate', CASE WHEN entered = 0 THEN 0 ELSE round(reached_store::numeric * 100 / entered, 2) END,
    'likely_opened_rate', CASE WHEN entered = 0 THEN 0 ELSE round(likely_opened::numeric * 100 / entered, 2) END
  ) FROM totals t),
  'byPlatform', COALESCE((SELECT rows FROM platform_rows), '[]'::jsonb),
  'byInApp', COALESCE((SELECT rows FROM inapp_rows), '[]'::jsonb),
  'bySource', COALESCE((SELECT rows FROM source_rows), '[]'::jsonb),
  'byRoute', COALESCE((SELECT rows FROM route_rows), '[]'::jsonb),
  'byDay', COALESCE((SELECT rows FROM day_rows), '[]'::jsonb)
);
$$;

REVOKE ALL ON FUNCTION public.download_event_stats(date, date, text) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.download_event_stats(date, date, text) TO service_role;

COMMIT;
NOTIFY pgrst, 'reload schema';
