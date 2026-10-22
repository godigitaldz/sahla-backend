-- Hotfix: keep order inserts compatible with clients that send zone_geojson.
-- Safe to run multiple times.
alter table if exists public.orders
  add column if not exists zone_geojson jsonb;
