-- Permanently delete download funnel tracking table and RPC
DROP FUNCTION IF EXISTS public.download_event_stats(date, date, text);
DROP TABLE IF EXISTS public.download_events CASCADE;
