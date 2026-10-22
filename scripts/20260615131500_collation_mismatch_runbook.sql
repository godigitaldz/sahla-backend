-- Supabase/Postgres collation mismatch runbook.
--
-- Your logs show:
--   database "postgres" has a collation version mismatch
--   created with 153.120, OS provides 153.121
--
-- This is usually caused by a managed OS/ICU library update. It is noisy and can
-- affect text sort/index correctness for collation-dependent indexes. Do this in
-- a low-traffic maintenance window, or ask Supabase Support to perform it if
-- permissions are restricted.

-- 1) Verify current database collation versions.
select
  datname,
  datcollate,
  datctype,
  datcollversion as stored_collation_version,
  pg_catalog.pg_database_collation_actual_version(oid) as os_collation_version,
  datcollversion is distinct from pg_catalog.pg_database_collation_actual_version(oid)
    as version_mismatch
from pg_database
where datname = current_database();

-- 2) Inspect indexes that may depend on text/collation behavior.
-- Review before any heavy maintenance. Large production databases may take time.
select
  schemaname,
  tablename,
  indexname,
  indexdef
from pg_indexes
where schemaname = 'public'
  and indexdef ~* '(text|character varying|varchar|name_ar|name_latin|name|description|address|city|state|wilaya)'
order by tablename, indexname;

-- 3) Maintenance action.
-- Prefer asking Supabase Support for the recommended managed-project procedure.
-- If you are allowed to run it yourself, use a maintenance window.
--
-- Option A: broad but potentially heavy:
-- REINDEX DATABASE postgres;
-- ALTER DATABASE postgres REFRESH COLLATION VERSION;
--
-- Option B: targeted:
-- REINDEX INDEX CONCURRENTLY public.<index_name>;
-- repeat for affected indexes, then:
-- ALTER DATABASE postgres REFRESH COLLATION VERSION;

-- 4) Verify warning should stop after reconnects.
-- select public.get_database_health_snapshot();

