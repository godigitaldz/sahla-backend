# Public Web Restaurant Ordering

## Deploy steps

1. Apply SQL migration (once per environment):
   ```bash
   SUPABASE_DB_URL='postgresql://...' node scripts/apply_public_web_migration.js
   ```
   Or run `scripts/20260619210000_public_web_ordering.sql` in Supabase SQL Editor.

2. Enable a restaurant:
   ```sql
   UPDATE public.restaurants
   SET public_slug = public.normalize_restaurant_public_slug(name),
       is_public_web_enabled = true
   WHERE id = '<restaurant_uuid>';
   ```

3. Ensure `system_config.web_order_fallback_customer_id` (or `manual_order_fallback_customer_id`) points to a valid `user_profiles.id`.

4. Deploy Vercel with builds for `web/` (Next.js) and `src/index.js` (Express). Routes:
   - `/_next/*` → Next.js static assets (**required** — otherwise CSS/JS 404 and the menu renders unstyled)
   - `/restaurants/*` → Next.js
   - `/api/public/*` → Next.js
   - `/api/*` → Express legacy API

## Pricing policy

- `orders.source = 'web'`, `manual_phone_order = false`, `service_fee = 0` always
- Web commission/tax: config-driven via `system_config` (default 0), optional per-restaurant override columns
- Delivery: subtotal + delivery_fee + delivery_tax + web commission
- Pickup: subtotal + web commission only

## Verification

```sql
SELECT column_name FROM information_schema.columns
WHERE table_name = 'orders' AND column_name IN ('source','public_order_code','client_request_id');

SELECT public.get_public_restaurant_by_slug('your-slug');
```

## Tests run locally

- `cd web && npm test` — pricing resolver, totals, line pricing, manipulation rejection
- `cd web && npm run build` — Next.js production build
