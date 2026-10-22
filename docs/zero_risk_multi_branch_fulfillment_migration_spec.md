# Zero-Risk Multi-Branch Fulfillment Migration Spec

## Goal

Enable one storefront (ex: Chillodose) to expose items fulfilled by multiple physical branches (ex: main kitchen + dessert kitchen), while keeping current customer and delivery apps stable until mobile rollout is ready.

This spec is backend-first and non-breaking:

- Existing orders keep single `restaurant_id` behavior.
- Existing mobile apps continue unchanged.
- New behavior is gated by flags and only activated for opted-in brands.

---

## Non-Negotiable Safety Rules

1. **No existing endpoint contract breaks**.
2. **No destructive schema changes** (additive only, no column drops/renames).
3. **Legacy mode remains default** for all restaurants.
4. **Dual-write / dual-read transition** before any behavior switch.
5. **Kill switch flags** allow instant rollback to current logic.

---

## Domain Model (Target)

- **Brand store**: the customer-facing storefront.
- **Fulfillment branch**: physical prep location responsible for some items.
- **Fulfillment plan**: server-computed mapping of order items to branch(es).

Legacy single-restaurant mode remains:

- `order.restaurant_id` = pickup/fee source (as today).

New branch-aware mode (when enabled):

- `order.restaurant_id` = storefront brand id (stable for old clients).
- `order.primary_fulfillment_restaurant_id` = pickup source for current delivery flows.
- optional: branch splits tracked in new tables.

---

## Additive SQL Schema Changes

Apply with normal migration workflow (Supabase SQL migration).

```sql
-- 1) Restaurant grouping + branch metadata
alter table if exists public.restaurants
  add column if not exists brand_group_id uuid,
  add column if not exists is_fulfillment_branch boolean not null default false,
  add column if not exists branch_role text
    check (branch_role in ('main_kitchen', 'dessert_kitchen', 'beverages', 'other')),
  add column if not exists serves_storefront_restaurant_id uuid references public.restaurants(id);

create index if not exists idx_restaurants_brand_group_id
  on public.restaurants(brand_group_id);

create index if not exists idx_restaurants_serves_storefront
  on public.restaurants(serves_storefront_restaurant_id);

-- 2) Menu item fulfillment override (optional; null = default storefront/main)
alter table if exists public.menu_items
  add column if not exists fulfillment_restaurant_id uuid references public.restaurants(id),
  add column if not exists fulfillment_mode text
    check (fulfillment_mode in ('default', 'branch_override'))
    default 'default';

create index if not exists idx_menu_items_fulfillment_restaurant_id
  on public.menu_items(fulfillment_restaurant_id);

-- 3) Orders: additive fields to support branch-aware assignment
alter table if exists public.orders
  add column if not exists fulfillment_mode text
    check (fulfillment_mode in ('legacy_single_restaurant', 'multi_branch'))
    default 'legacy_single_restaurant',
  add column if not exists primary_fulfillment_restaurant_id uuid references public.restaurants(id),
  add column if not exists fulfillment_plan_version integer not null default 1,
  add column if not exists fulfillment_debug jsonb not null default '{}'::jsonb;

create index if not exists idx_orders_primary_fulfillment_restaurant_id
  on public.orders(primary_fulfillment_restaurant_id);

-- 4) Order item branch resolution snapshot
alter table if exists public.order_items
  add column if not exists fulfillment_restaurant_id uuid references public.restaurants(id);

create index if not exists idx_order_items_fulfillment_restaurant_id
  on public.order_items(fulfillment_restaurant_id);

-- 5) Optional split ledger for future multi-pickup
create table if not exists public.order_fulfillment_splits (
  id uuid primary key default gen_random_uuid(),
  order_id uuid not null references public.orders(id) on delete cascade,
  fulfillment_restaurant_id uuid not null references public.restaurants(id),
  item_count integer not null default 0,
  subtotal numeric(12,2) not null default 0,
  status text not null default 'pending'
    check (status in ('pending', 'accepted', 'preparing', 'ready', 'picked_up', 'delivered', 'cancelled')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create unique index if not exists uq_order_fulfillment_splits_order_branch
  on public.order_fulfillment_splits(order_id, fulfillment_restaurant_id);

create index if not exists idx_order_fulfillment_splits_order_id
  on public.order_fulfillment_splits(order_id);
```

---

## Data Backfill Plan (Safe / Idempotent)

Run in batches, repeatable:

1. Set `restaurants.is_fulfillment_branch = false` where null (already default).
2. For pilot brand:
   - assign same `brand_group_id` to storefront + branches.
   - set dessert branch `is_fulfillment_branch = true`, `branch_role = 'dessert_kitchen'`.
3. Set `menu_items.fulfillment_restaurant_id` for dessert items only.
4. Backfill legacy orders:
   - `orders.primary_fulfillment_restaurant_id = orders.restaurant_id` where null.
   - `orders.fulfillment_mode = 'legacy_single_restaurant'`.
   - `order_items.fulfillment_restaurant_id = orders.restaurant_id` where null.

Backfill SQL sketch:

```sql
update public.orders
set
  primary_fulfillment_restaurant_id = restaurant_id,
  fulfillment_mode = coalesce(fulfillment_mode, 'legacy_single_restaurant')
where primary_fulfillment_restaurant_id is null;

update public.order_items oi
set fulfillment_restaurant_id = o.restaurant_id
from public.orders o
where oi.order_id = o.id
  and oi.fulfillment_restaurant_id is null;
```

---

## Backend Endpoint Changes (Non-Breaking)

Keep existing endpoints; add optional fields and internal endpoints.

## 1) Existing create order path

`POST /api/orders` (or current equivalent)

No required payload change for old clients.

Server behavior:

- If flags disabled: current logic unchanged.
- If enabled for restaurant:
  - resolve per-item fulfillment branch using `menu_items.fulfillment_restaurant_id`.
  - set `orders.primary_fulfillment_restaurant_id` using resolver policy.
  - persist `order_items.fulfillment_restaurant_id`.
  - keep `orders.restaurant_id` populated for compatibility.

Response additions (optional fields, backward compatible):

- `fulfillment_mode`
- `primary_fulfillment_restaurant_id`
- `has_multi_branch_items`

## 2) New internal resolution endpoint (for admin tools/backend QA)

`POST /internal/orders/resolve-fulfillment`

Request:

```json
{
  "storefront_restaurant_id": "uuid",
  "items": [{"menu_item_id": "uuid", "quantity": 1}],
  "delivery_address": {"latitude": 0, "longitude": 0}
}
```

Response:

```json
{
  "mode": "legacy_single_restaurant|multi_branch",
  "primary_fulfillment_restaurant_id": "uuid",
  "splits": [
    {"fulfillment_restaurant_id": "uuid", "item_count": 2, "subtotal": 1200}
  ],
  "distance_fee_source_restaurant_id": "uuid"
}
```

## 3) Admin patch endpoint (owner/admin only)

`PATCH /api/admin/menu-items/:id/fulfillment`

Body:

```json
{
  "fulfillment_mode": "default|branch_override",
  "fulfillment_restaurant_id": "uuid|null"
}
```

Use this to map dessert items to dessert branch without mobile update.

---

## Fulfillment Resolver Policy (v1, mobile-safe)

When multi-branch mode is enabled:

1. Resolve each item:
   - `branch_override` -> `menu_items.fulfillment_restaurant_id`
   - else -> storefront/main restaurant id
2. Determine `primary_fulfillment_restaurant_id`:
   - if all items same branch -> that branch
   - if mixed branches -> choose policy:
     - **safe default**: storefront/main branch
3. Delivery fee source:
   - v1 safe mode: use `primary_fulfillment_restaurant_id` only.
4. Courier assignment:
   - current delivery flow assigns from `orders.primary_fulfillment_restaurant_id`.

This keeps delivery app stable while backend starts storing branch truth.

---

## Rollout Flags (Required)

All flags default `false`.

- `FF_MULTI_BRANCH_SCHEMA_READS`
  - backend can read new columns/tables but does not change behavior.
- `FF_MULTI_BRANCH_RESOLVER_SHADOW`
  - run resolver in shadow mode, log result only.
- `FF_MULTI_BRANCH_WRITE_ORDER_ITEM_BRANCH`
  - write `order_items.fulfillment_restaurant_id` (still legacy operational behavior).
- `FF_MULTI_BRANCH_WRITE_PRIMARY_BRANCH`
  - write `orders.primary_fulfillment_restaurant_id`.
- `FF_MULTI_BRANCH_ASSIGNMENT_USE_PRIMARY_BRANCH`
  - delivery assignment/pickup uses `primary_fulfillment_restaurant_id`.
- `FF_MULTI_BRANCH_FEE_USE_PRIMARY_BRANCH`
  - fee calculation uses `primary_fulfillment_restaurant_id`.
- `FF_MULTI_BRANCH_ENABLE_FOR_BRAND_GROUPS`
  - comma-separated UUID allowlist.
- `FF_MULTI_BRANCH_HARD_DISABLE`
  - global kill switch; force legacy behavior immediately.

---

## Rollout Phases

## Phase 0: Deploy Schema (No Behavior Change)

- Run additive SQL migration.
- Release backend reading nullable fields safely.
- Keep all flags OFF.

## Phase 1: Shadow Resolver

- Enable:
  - `FF_MULTI_BRANCH_SCHEMA_READS=true`
  - `FF_MULTI_BRANCH_RESOLVER_SHADOW=true`
- Log diffs:
  - legacy pickup restaurant vs resolved primary branch.
- No user-visible change.

## Phase 2: Write-Only Pilot

- Enable for one brand group:
  - `FF_MULTI_BRANCH_WRITE_ORDER_ITEM_BRANCH=true`
  - `FF_MULTI_BRANCH_WRITE_PRIMARY_BRANCH=true`
  - allowlist includes Chillodose brand group.
- Delivery assignment and fee still legacy.

## Phase 3: Backend Operational Switch (Still Mobile-Transparent)

- Enable:
  - `FF_MULTI_BRANCH_ASSIGNMENT_USE_PRIMARY_BRANCH=true`
  - `FF_MULTI_BRANCH_FEE_USE_PRIMARY_BRANCH=true`
- Keep customer/delivery payload shape unchanged.
- Validate metrics and support tickets for pilot window.

## Phase 4: Mobile-Aware Enhancements (Later)

- Introduce UX for mixed-branch cart and optional split pickups.
- At this point backend already has data model and history.

---

## Observability / Logic Check Checklist

Track these counters per flag phase:

- `% orders with mixed fulfillment branches`
- `% orders where primary branch != storefront restaurant`
- `% fee source branch changed vs legacy`
- courier assignment failures by branch
- order acceptance delay by branch
- cancellation/refund rate changes (pilot vs control)

Structured logs per order:

- `order_id`
- `storefront_restaurant_id`
- `primary_fulfillment_restaurant_id`
- `split_count`
- `resolver_version`
- `flags_snapshot`

---

## Regression Guardrails

1. If resolver fails, fallback to legacy:
   - `primary_fulfillment_restaurant_id = restaurant_id`.
2. If `FF_MULTI_BRANCH_HARD_DISABLE=true`, bypass all new logic.
3. Never reject order solely due to missing new metadata in early phases.
4. Keep idempotent writes for create-order retries.

---

## Test Plan (Backend Only)

Minimum automated suite:

1. Legacy order (all flags off) => identical DB writes and response.
2. Shadow mode on => no operational change, logs populated.
3. Write mode on => order items contain `fulfillment_restaurant_id`.
4. Assignment switch on => courier pickup branch uses `primary_fulfillment_restaurant_id`.
5. Kill switch on => behavior instantly reverts to legacy.
6. Resolver fallback path on DB mismatch => order still created legacy-safe.

---

## Immediate Execution Plan

1. Apply SQL migration in staging.
2. Implement resolver module + shadow logging only.
3. Add flag plumbing and kill switch.
4. Add write-only mode for pilot brand group.
5. Promote to production with all behavior switches OFF.
6. Enable phases gradually with monitoring.

