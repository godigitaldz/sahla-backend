-- Verification queries for the slow rows shown in Reports > Top slow queries.
-- Run in Supabase SQL Editor before adding new indexes, so we avoid duplicate or
-- unused index bloat.

-- Current indexes for order detail embeds.
select
  schemaname,
  tablename,
  indexname,
  indexdef
from pg_indexes
where schemaname = 'public'
  and tablename in ('orders', 'order_items', 'menu_items', 'restaurants')
order by tablename, indexname;

-- Expected high-value index candidates for slow order/menu browse paths:
-- order_items(order_id) for order detail embeds
-- orders(status, created_at desc) for dashboard pending/delivery filters
-- orders(restaurant_id, status, created_at desc) for restaurant dashboards
-- menu_items(restaurant_id, is_available) for restaurant menus
-- menu_items(category_id), menu_items(cuisine_type_id) for filters if used
-- restaurants(wilaya, state, is_open), restaurants(home_food, wilaya, state, is_open)

-- pg_stat_statements extension location and availability.
select
  e.extname,
  n.nspname as schema_name,
  e.extversion
from pg_extension e
join pg_namespace n on n.oid = e.extnamespace
where e.extname = 'pg_stat_statements';

-- Function existence for app-owned slow RPCs/jobs.
select
  p.proname,
  n.nspname as schema_name,
  pg_get_function_identity_arguments(p.oid) as args
from pg_proc p
join pg_namespace n on n.oid = p.pronamespace
where n.nspname = 'public'
  and p.proname in (
    'list_restaurants_ranked_v2',
    'list_menu_items_ranked',
    'release_due_preorders'
  )
order by p.proname;

