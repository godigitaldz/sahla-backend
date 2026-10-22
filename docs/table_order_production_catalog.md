# Table Order — Production Catalog Inspection

Run these read-only queries in **Supabase SQL Editor** before applying table-order migrations.
Record results in the sign-off section at the bottom.

## 1. Orders triggers

```sql
SELECT
  t.tgname AS trigger_name,
  p.proname AS function_name,
  CASE t.tgenabled WHEN 'O' THEN 'enabled' ELSE t.tgenabled::text END AS status,
  pg_get_triggerdef(t.oid, true) AS definition
FROM pg_trigger t
JOIN pg_class c ON c.oid = t.tgrelid
JOIN pg_namespace n ON n.oid = c.relnamespace
JOIN pg_proc p ON p.oid = t.tgfoid
WHERE n.nspname = 'public'
  AND c.relname = 'orders'
  AND NOT t.tgisinternal
ORDER BY t.tgname;
```

## 2. Financial trigger functions

```sql
SELECT DISTINCT
  p.proname AS function_name,
  CASE
    WHEN pg_get_functiondef(p.oid) ILIKE '%NEW.source IS NOT DISTINCT FROM ''web''%' THEN 'web_skip_present'
    ELSE 'needs_web_skip'
  END AS web_guard_status
FROM pg_trigger t
JOIN pg_proc p ON p.oid = t.tgfoid
JOIN pg_class c ON c.oid = t.tgrelid
JOIN pg_namespace n ON n.oid = c.relnamespace
WHERE n.nspname = 'public'
  AND c.relname = 'orders'
  AND NOT t.tgisinternal
ORDER BY 1;
```

## 3. fulfillment_type constraint type

```sql
SELECT
  conname,
  pg_get_constraintdef(oid) AS definition
FROM pg_constraint
WHERE conrelid = 'public.orders'::regclass
  AND (conname ILIKE '%fulfillment%' OR pg_get_constraintdef(oid) ILIKE '%fulfillment%');

SELECT fulfillment_type, count(*) FROM public.orders GROUP BY 1 ORDER BY 2 DESC;
```

## 4. RLS policies

```sql
SELECT schemaname, tablename, policyname, permissive, roles, cmd, qual, with_check
FROM pg_policies
WHERE schemaname = 'public'
  AND tablename IN ('orders', 'order_items', 'restaurants')
ORDER BY tablename, policyname;
```

## 5. RPC grants

```sql
SELECT
  p.proname,
  p.prosecdef AS security_definer,
  array_agg(DISTINCT r.rolname) AS grantees
FROM pg_proc p
JOIN pg_namespace n ON n.oid = p.pronamespace
LEFT JOIN aclexplode(p.proacl) a ON true
LEFT JOIN pg_roles r ON r.oid = a.grantee
WHERE n.nspname = 'public'
  AND p.proname IN (
    'create_public_web_order',
    'get_public_restaurant_by_slug',
    'get_public_restaurant_menu'
  )
GROUP BY p.proname, p.prosecdef;
```

## 6. Dispatch columns

```sql
SELECT column_name, data_type
FROM information_schema.columns
WHERE table_schema = 'public'
  AND table_name = 'orders'
  AND column_name IN (
    'dispatch_active', 'dispatch_next_run_at', 'dispatch_attempt',
    'fulfillment_type', 'source', 'delivery_person_id'
  );
```

## 7. Codebase-derived findings (offline inspection)

| Finding | Risk for table orders | Mitigation in migration |
|---------|----------------------|-------------------------|
| `fulfillment_type` unknown → delivery in Flutter `order.dart` | Table orders enter courier pool | Harden consumers to `eq delivery`; add `table` enum |
| Courier queries use `neq pickup` | Table included | Change to `eq delivery` |
| `order-dispatch-worker` ignores fulfillment | Table may dispatch | Add early skip unless delivery |
| Financial triggers branch pickup vs else | Table gets delivery net math | Add `table` branch + `web_table` source skip |
| In-memory Vercel rate limits | Scan brute-force | Upstash limiter for table paths |
| `create_public_web_order` only allows delivery/pickup | Cannot reuse for table | Separate `create_public_table_order` |

## Sign-off checklist

- [ ] All orders triggers documented
- [ ] Financial functions audited for `table` / `web_table` branches
- [ ] `fulfillment_type` constraint type confirmed (text check vs enum)
- [ ] RLS policies reviewed for new tables
- [ ] Dispatch guard trigger deployed
- [ ] Hardened Flutter + workers deployed **before** `table_ordering_enabled = true`

**Note:** Automated live inspection may fail when outbound DNS is restricted. Run queries manually in Supabase dashboard.
