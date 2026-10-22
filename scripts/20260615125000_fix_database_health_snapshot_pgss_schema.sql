-- Fix Reports Dashboard DB health RPC on Supabase projects where
-- pg_stat_statements is installed outside the public schema.
-- Verification:
--   select public.get_database_health_snapshot();

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
      jsonb_build_object('state', coalesce(state, 'unknown'), 'count', cnt)
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
      jsonb_build_object('mode', mode, 'granted', granted, 'count', cnt)
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

REVOKE ALL ON FUNCTION public.get_database_health_snapshot() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_database_health_snapshot() TO service_role;

