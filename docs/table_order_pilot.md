# Table Order Pilot Rollout

## Prerequisites

1. Apply SQL migrations (in order) via `scripts/apply_table_ordering_migration.js` or Supabase SQL Editor:
   - through `scripts/20260622140800_orders_fulfillment_type_table.sql` (includes `table` fulfillment + portal password)
2. Set Vercel env on Next.js project:
   - `UPSTASH_REDIS_REST_URL`
   - `UPSTASH_REDIS_REST_TOKEN`
   - `NEXT_PUBLIC_SUPABASE_URL`
   - `NEXT_PUBLIC_SUPABASE_ANON_KEY`
3. Deploy hardened Flutter app + workers **before** enabling any restaurant.

## Enable pilot restaurant

```sql
-- Replace with pilot restaurant UUID
UPDATE public.restaurants
SET table_ordering_enabled = true
WHERE id = '<pilot-restaurant-uuid>';

SELECT public.rotate_restaurant_venue_codes();
```

## QA checklist

| # | Test | Pass |
|---|------|------|
| 1 | QR without venue code | Blocked |
| 2 | Old venue code | Rejected |
| 3 | Current venue code | Session + menu |
| 4 | Table order totals | Subtotal only |
| 5 | Courier pool | Excludes table |
| 6 | Session expiry | Cart kept, submit blocked, Arabic message |
| 7 | Regenerated QR | Old code fails |
| 8 | CSRF missing on order POST | 403 |
| 9 | Checkout confirm | Order created (`fulfillment_type=table`) |

## Verification

```sql
-- Must include table
SELECT pg_get_constraintdef(oid)
FROM pg_constraint
WHERE conrelid = 'public.orders'::regclass
  AND conname = 'orders_fulfillment_type_check';

SELECT id, fulfillment_type, source, table_id
FROM public.orders
WHERE fulfillment_type = 'table'
ORDER BY created_at DESC
LIMIT 5;
```

## Rollback

```sql
UPDATE public.restaurants SET table_ordering_enabled = false WHERE id = '<pilot-restaurant-uuid>';
```

Revoke active sessions:

```sql
UPDATE public.table_order_sessions SET revoked_at = now() WHERE revoked_at IS NULL;
```
