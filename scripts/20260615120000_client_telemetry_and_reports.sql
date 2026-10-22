-- Client telemetry + reports dashboard schema
-- Deploy via Supabase SQL Editor or migration pipeline before enabling reports.

CREATE TABLE IF NOT EXISTS public.client_telemetry_events (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  event_type text NOT NULL CHECK (event_type IN (
    'app_launch',
    'session_open',
    'session_heartbeat',
    'crash',
    'performance_sample'
  )),
  occurred_at timestamptz NOT NULL DEFAULT now(),
  user_id uuid NULL,
  device_id text NOT NULL,
  platform text NULL,
  app_version text NULL,
  build_number text NULL,
  session_id text NULL,
  duration_ms integer NULL,
  error_message text NULL,
  error_hash text NULL,
  payload jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_cte_occurred_at
  ON public.client_telemetry_events (occurred_at DESC);

CREATE INDEX IF NOT EXISTS idx_cte_event_type_occurred
  ON public.client_telemetry_events (event_type, occurred_at DESC);

CREATE INDEX IF NOT EXISTS idx_cte_device_id
  ON public.client_telemetry_events (device_id);

CREATE INDEX IF NOT EXISTS idx_cte_platform_occurred
  ON public.client_telemetry_events (platform, occurred_at DESC);

ALTER TABLE public.client_telemetry_events ENABLE ROW LEVEL SECURITY;

-- No anon/authenticated policies: ingestion and reads go through service role / SECURITY DEFINER RPCs.

CREATE OR REPLACE FUNCTION public.get_client_telemetry_day_summary(
  p_start timestamptz,
  p_end timestamptz
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  result jsonb;
  auth_sessions_count bigint := 0;
BEGIN
  IF to_regclass('public.user_sessions') IS NOT NULL THEN
    SELECT count(*)::bigint INTO auth_sessions_count
    FROM public.user_sessions
    WHERE created_at >= p_start AND created_at < p_end;
  END IF;

  SELECT jsonb_build_object(
    'app_launches',
      (SELECT count(*)::bigint FROM client_telemetry_events
       WHERE event_type = 'app_launch' AND occurred_at >= p_start AND occurred_at < p_end),
    'sessions_opened',
      (SELECT count(*)::bigint FROM client_telemetry_events
       WHERE event_type = 'session_open' AND occurred_at >= p_start AND occurred_at < p_end),
    'session_heartbeats',
      (SELECT count(*)::bigint FROM client_telemetry_events
       WHERE event_type = 'session_heartbeat' AND occurred_at >= p_start AND occurred_at < p_end),
    'crashes',
      (SELECT count(*)::bigint FROM client_telemetry_events
       WHERE event_type = 'crash' AND occurred_at >= p_start AND occurred_at < p_end),
    'performance_samples',
      (SELECT count(*)::bigint FROM client_telemetry_events
       WHERE event_type = 'performance_sample' AND occurred_at >= p_start AND occurred_at < p_end),
    'active_devices',
      (SELECT count(DISTINCT device_id)::bigint FROM client_telemetry_events
       WHERE occurred_at >= p_start AND occurred_at < p_end),
    'unique_users',
      (SELECT count(DISTINCT user_id)::bigint FROM client_telemetry_events
       WHERE user_id IS NOT NULL AND occurred_at >= p_start AND occurred_at < p_end),
    'avg_startup_ms',
      (SELECT round(avg(duration_ms))::int FROM client_telemetry_events
       WHERE event_type = 'app_launch' AND duration_ms IS NOT NULL
         AND occurred_at >= p_start AND occurred_at < p_end),
    'slow_startup_count',
      (SELECT count(*)::bigint FROM client_telemetry_events
       WHERE event_type = 'app_launch' AND duration_ms > 3000
         AND occurred_at >= p_start AND occurred_at < p_end),
    'auth_sessions_proxy', auth_sessions_count
  ) INTO result;

  RETURN result;
END;
$$;

CREATE OR REPLACE FUNCTION public.get_client_telemetry_platform_breakdown(
  p_start timestamptz,
  p_end timestamptz
)
RETURNS jsonb
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT coalesce(
    jsonb_agg(
      jsonb_build_object(
        'platform', coalesce(platform, 'unknown'),
        'events', event_count,
        'devices', device_count
      )
      ORDER BY event_count DESC
    ),
    '[]'::jsonb
  )
  FROM (
    SELECT
      platform,
      count(*)::bigint AS event_count,
      count(DISTINCT device_id)::bigint AS device_count
    FROM client_telemetry_events
    WHERE occurred_at >= p_start AND occurred_at < p_end
    GROUP BY platform
  ) s;
$$;

CREATE OR REPLACE FUNCTION public.get_client_telemetry_version_breakdown(
  p_start timestamptz,
  p_end timestamptz
)
RETURNS jsonb
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT coalesce(
    jsonb_agg(
      jsonb_build_object(
        'app_version', coalesce(app_version, 'unknown'),
        'build_number', coalesce(build_number, 'unknown'),
        'launches', launch_count,
        'crashes', crash_count
      )
      ORDER BY launch_count DESC
    ),
    '[]'::jsonb
  )
  FROM (
    SELECT
      app_version,
      build_number,
      count(*) FILTER (WHERE event_type = 'app_launch')::bigint AS launch_count,
      count(*) FILTER (WHERE event_type = 'crash')::bigint AS crash_count
    FROM client_telemetry_events
    WHERE occurred_at >= p_start AND occurred_at < p_end
      AND event_type IN ('app_launch', 'crash')
    GROUP BY app_version, build_number
  ) s;
$$;

CREATE OR REPLACE FUNCTION public.get_database_health_snapshot()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, extensions, pg_catalog
AS $$
DECLARE
  db_stats jsonb;
  collation_stats jsonb := '{}'::jsonb;
  conn_stats jsonb;
  table_stats jsonb;
  index_stats jsonb;
  lock_stats jsonb;
  slow_queries jsonb;
  has_pgss boolean := false;
  pgss_schema text;
  actual_collation_version text;
BEGIN
  BEGIN
    EXECUTE
      'select pg_catalog.pg_database_collation_actual_version(oid) from pg_catalog.pg_database where datname = current_database()'
      INTO actual_collation_version;
  EXCEPTION
    WHEN undefined_function THEN
      actual_collation_version := null;
  END;

  BEGIN
    EXECUTE $sql$
      SELECT jsonb_build_object(
        'collation_name', datcollate::text,
        'ctype_name', datctype::text,
        'collation_version', datcollversion::text,
        'os_collation_version', $1,
        'collation_version_mismatch',
          CASE
            WHEN datcollversion IS NULL OR $1 IS NULL THEN null
            ELSE datcollversion IS DISTINCT FROM $1
          END
      )
      FROM pg_catalog.pg_database
      WHERE datname = current_database()
    $sql$
    INTO collation_stats
    USING actual_collation_version;
  EXCEPTION
    WHEN SQLSTATE '42703' THEN
      collation_stats := jsonb_build_object(
        'os_collation_version', actual_collation_version,
        'collation_version_mismatch', null
      );
    WHEN SQLSTATE '42P01' THEN
      collation_stats := jsonb_build_object(
        'os_collation_version', actual_collation_version,
        'collation_version_mismatch', null
      );
  END;

  SELECT jsonb_build_object(
    'database_name', datname,
    'database_size_bytes', pg_database_size(datname),
    'num_backends', numbackends,
    'xact_commit', xact_commit,
    'xact_rollback', xact_rollback,
    'rollback_ratio',
      CASE WHEN (xact_commit + xact_rollback) > 0
        THEN round(100.0 * xact_rollback / (xact_commit + xact_rollback), 2)
        ELSE null END,
    'blks_read', blks_read,
    'blks_hit', blks_hit,
    'cache_hit_ratio',
      CASE WHEN (blks_hit + blks_read) > 0
        THEN round(100.0 * blks_hit / (blks_hit + blks_read), 2)
        ELSE null END,
    'index_hit_ratio',
      (
        SELECT CASE WHEN (sum(idx_blks_hit) + sum(idx_blks_read)) > 0
          THEN round(100.0 * sum(idx_blks_hit) / (sum(idx_blks_hit) + sum(idx_blks_read)), 2)
          ELSE null END
        FROM pg_statio_user_indexes
      ),
    'tup_returned', tup_returned,
    'tup_fetched', tup_fetched,
    'tup_inserted', tup_inserted,
    'tup_updated', tup_updated,
    'tup_deleted', tup_deleted,
    'deadlocks', deadlocks,
    'temp_files', temp_files,
    'temp_bytes', temp_bytes
  ) INTO db_stats
  FROM pg_stat_database
  WHERE datname = current_database();

  db_stats := db_stats || collation_stats;

  SELECT coalesce(
    jsonb_agg(
      jsonb_build_object(
        'state', coalesce(state, 'unknown'),
        'count', cnt
      )
      ORDER BY cnt DESC
    ),
    '[]'::jsonb
  ) INTO conn_stats
  FROM (
    SELECT state, count(*)::int AS cnt
    FROM pg_stat_activity
    WHERE datname = current_database()
    GROUP BY state
  ) c;

  SELECT coalesce(
    jsonb_agg(
      jsonb_build_object(
        'mode', mode,
        'granted', granted,
        'count', cnt
      )
      ORDER BY cnt DESC
    ),
    '[]'::jsonb
  ) INTO lock_stats
  FROM (
    SELECT mode, granted, count(*)::int AS cnt
    FROM pg_locks
    GROUP BY mode, granted
  ) l;

  SELECT coalesce(
    jsonb_agg(
      jsonb_build_object(
        'table', relname,
        'seq_scan', seq_scan,
        'idx_scan', idx_scan,
        'n_live_tup', n_live_tup,
        'n_dead_tup', n_dead_tup,
        'dead_tuple_ratio',
          CASE WHEN (n_live_tup + n_dead_tup) > 0
            THEN round(100.0 * n_dead_tup / (n_live_tup + n_dead_tup), 2)
            ELSE 0 END,
        'last_vacuum', last_vacuum,
        'last_autovacuum', last_autovacuum,
        'last_analyze', last_analyze,
        'last_autoanalyze', last_autoanalyze,
        'total_bytes', pg_total_relation_size(relid)
      )
      ORDER BY pg_total_relation_size(relid) DESC
    ),
    '[]'::jsonb
  ) INTO table_stats
  FROM (
    SELECT
      relid,
      relname,
      seq_scan,
      idx_scan,
      n_live_tup,
      n_dead_tup,
      last_vacuum,
      last_autovacuum,
      last_analyze,
      last_autoanalyze
    FROM pg_stat_user_tables
    WHERE schemaname = 'public'
    ORDER BY pg_total_relation_size(relid) DESC
    LIMIT 15
  ) t;

  SELECT coalesce(
    jsonb_agg(
      jsonb_build_object(
        'table', relname,
        'index', indexrelname,
        'idx_scan', idx_scan,
        'idx_tup_read', idx_tup_read,
        'idx_tup_fetch', idx_tup_fetch,
        'index_bytes', pg_relation_size(indexrelid)
      )
      ORDER BY pg_relation_size(indexrelid) DESC
    ),
    '[]'::jsonb
  ) INTO index_stats
  FROM (
    SELECT relname, indexrelname, idx_scan, idx_tup_read, idx_tup_fetch, indexrelid
    FROM pg_stat_user_indexes
    WHERE schemaname = 'public'
    ORDER BY pg_relation_size(indexrelid) DESC
    LIMIT 20
  ) i;

  SELECT n.nspname
    INTO pgss_schema
  FROM pg_extension e
  JOIN pg_namespace n ON n.oid = e.extnamespace
  WHERE e.extname = 'pg_stat_statements';

  has_pgss := pgss_schema IS NOT NULL;

  IF has_pgss THEN
    EXECUTE format(
      $sql$
        SELECT coalesce(
          jsonb_agg(
            jsonb_build_object(
              'query', left(query, 240),
              'calls', calls,
              'mean_time_ms', round(mean_exec_time::numeric, 2),
              'total_time_ms', round(total_exec_time::numeric, 2),
              'rows', rows
            )
            ORDER BY total_exec_time DESC
          ),
          '[]'::jsonb
        )
        FROM (
          SELECT query, calls, mean_exec_time, total_exec_time, rows
          FROM %I.pg_stat_statements
          WHERE dbid = (SELECT oid FROM pg_database WHERE datname = current_database())
          ORDER BY total_exec_time DESC
          LIMIT 10
        ) q
      $sql$,
      pgss_schema
    ) INTO slow_queries;
  ELSE
    slow_queries := '[]'::jsonb;
  END IF;

  RETURN jsonb_build_object(
    'captured_at', now(),
    'database', db_stats,
    'connections', conn_stats,
    'locks', lock_stats,
    'top_tables', table_stats,
    'top_indexes', index_stats,
    'slow_queries', slow_queries,
    'pg_stat_statements_enabled', has_pgss,
    'pg_stat_statements_schema', pgss_schema,
    'compute_metrics', jsonb_build_object(
      'cpu_available', false,
      'ram_available', false,
      'reason', 'Supabase CPU/RAM metrics are platform metrics and are not exposed through Postgres SQL. Connect the Supabase Management/Observability API or log export to show them here.'
    )
  );
END;
$$;

REVOKE ALL ON FUNCTION public.get_client_telemetry_day_summary(timestamptz, timestamptz) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.get_client_telemetry_platform_breakdown(timestamptz, timestamptz) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.get_client_telemetry_version_breakdown(timestamptz, timestamptz) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.get_database_health_snapshot() FROM PUBLIC;

GRANT EXECUTE ON FUNCTION public.get_client_telemetry_day_summary(timestamptz, timestamptz) TO service_role;
GRANT EXECUTE ON FUNCTION public.get_client_telemetry_platform_breakdown(timestamptz, timestamptz) TO service_role;
GRANT EXECUTE ON FUNCTION public.get_client_telemetry_version_breakdown(timestamptz, timestamptz) TO service_role;
GRANT EXECUTE ON FUNCTION public.get_database_health_snapshot() TO service_role;

-- Verification:
-- select to_regclass('public.client_telemetry_events');
-- select public.get_client_telemetry_day_summary(now() - interval '1 day', now());
-- select public.get_database_health_snapshot();
-- select * from pg_extension where extname = 'pg_stat_statements';
