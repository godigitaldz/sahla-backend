# Sahla Admin Push Alerts Operations & Architecture Runbook

## Overview

Sahla Admin Push Alerts inform operations staff of critical workflow milestones:
1. **Pending Order Escalation (2m)** (`admin_order_pending_2m`): Order is pending restaurant acceptance for > 2 minutes.
2. **Pending Order Escalation (5m)** (`admin_order_pending_5m`): Order remains pending for > 5 minutes.
3. **Preparing Unassigned Courier (5m)** (`admin_preparing_unassigned_5m`): Food order is preparing/ready for > 5 minutes without an assigned courier.
4. **Preparing Assigned Delayed (20m)** (`admin_preparing_assigned_20m`): Food order is assigned to a courier for > 20 minutes but has not been picked up.
5. **Delivery Picked Up Delayed (15m)** (`admin_delivery_picked_up_15m`): Order was picked up by courier > 15 minutes ago and remains undelivered.
6. **Parcel Waiting (15m)** (`admin_parcel_waiting_15m`): Parcel order waiting for courier assignment > 15 minutes.
7. **Customer Auto-Cancel (15m)** (`order_auto_cancelled_15m`): Order unaccepted after 15 minutes is automatically cancelled.

---

## Architecture & Root Cause Fix

### Previous Defect
Previously, in-process interval timers were disabled on Vercel (`VERCEL === '1'`). Vercel Cron on the Hobby plan was restricted to once a day (`0 6 * * *`), and GitHub Actions cron runners had jitter/delays (15–45 minutes). To work around this, escalation polling was attached as an unawaited side-effect (`setImmediate`) to the `/api/performance/alerts` route when the Performance web dashboard was open (`PERFORMANCE_OPEN_DASHBOARD_POLL_MS`). Consequently, closing the browser tab completely halted alert detection and delivery.

### Current Architecture
1. **Dashboard Read-Only Isolation**: The `/api/performance/alerts` endpoint is 100% read-only. All side-effect polling and dashboard-activity throttles have been eliminated.
2. **Always-On Server-Side Scheduling**:
   - Primary: **Upstash QStash 1-Minute Schedule** hitting `POST /api/internal/pending-orders-poll` with `Authorization: Bearer <CRON_SECRET>`.
   - Secondary / Alternative: **Supabase `pg_cron` + `pg_net`** directly from PostgreSQL.
   - Tertiary: **External Webhook / Monitoring Service** (e.g. cron-job.org, BetterStack, EasyCron) or **GitHub Actions**.
3. **Atomic Concurrency & Deduplication**:
   - Every alert family shares the exact canonical dispatch key with QStash lifecycle jobs in `notification_dispatch_log` (`dispatch_key` UNIQUE index).
   - In-flight reservation lease (`60_000ms` TTL) prevents concurrent runners, overlapping serverless instances, or retried requests from double-sending pushes.
   - Dispatches are marked `'sent'` ONLY upon confirmed provider acceptance (`pushSendSucceeded` with `total_sent > 0`).
4. **Flutter FCM Contract**:
   - Notifications carry `{ type: 'admin_order_alert', stage, flow, order_id, order_number }`.
   - Android maps to high-importance channel `orders_v2` with loud alert sound `new_order_alert.mp3`.
   - iOS receives `apns-push-type: alert`, `apns-priority: 10`, and `new_order_alert.caf`.
   - Client foreground handler presents local notification; background/terminated states display via OS system tray.

---

## Operating Instructions & Scheduler Setup

### Option A: Upstash QStash Schedule (Recommended & Built-in)

The backend code automatically verifies and provisions the QStash schedule if `QSTASH_TOKEN` and `CRON_SECRET` are configured.

To inspect or manually ensure the schedule from the command line:

```bash
# Ensure 1-minute schedule exists
node scripts/setup_qstash_cron.js

# List all active QStash schedules
node scripts/setup_qstash_cron.js --list

# Delete an obsolete schedule if needed
node scripts/setup_qstash_cron.js --delete <scheduleId>
```

Alternatively, invoke the authenticated endpoint via HTTP:
```bash
curl -X POST https://sahla-backend.vercel.app/api/internal/cron/ensure-schedule \
  -H "Authorization: Bearer <CRON_SECRET>" \
  -H "Content-Type: application/json" \
  -d '{"cron":"* * * * *"}'
```

---

### Option B: Supabase `pg_cron` (Database-Native)

If you prefer scheduling directly inside PostgreSQL without external dependencies:

1. Open **Supabase Dashboard** > **Database** > **Extensions**.
2. Enable `pg_cron` and `pg_net`.
3. Open **SQL Editor** and run the contents of `scripts/setup_supabase_pg_cron.sql` (substituting `<YOUR_CRON_SECRET>`).

---

### Option C: External Webhook (cron-job.org / BetterStack)

Configure any external HTTP monitor or cron service:
- **URL**: `https://sahla-backend.vercel.app/api/internal/pending-orders-poll`
- **Method**: `POST`
- **Schedule**: Every 1 minute (`* * * * *`)
- **Headers**:
  - `Authorization: Bearer <CRON_SECRET>`
  - `Content-Type: application/json`

---

## Environment Variables Reference

| Variable | Required | Description |
|---|---|---|
| `CRON_SECRET` | Yes | Bearer token for authenticating scheduled cron & lifecycle endpoints |
| `QSTASH_TOKEN` | Recommended | Token for Upstash QStash lifecycle jobs & recurring schedule |
| `ORDER_LIFECYCLE_WEBHOOK_URL` | Yes | Backend base URL (e.g. `https://sahla-backend.vercel.app`) |
| `ADMIN_ORDER_ALERT_USER_IDS` | Optional | Comma-separated list of explicit auth user UUIDs to receive admin push alerts |
| `ENABLE_PENDING_ORDERS_POLLER` | Optional | Defaults to `true`. Set to `false` to disable pending orders poller |
| `ENABLE_PICKUP_DELAY_ADMIN_ALERTS` | Optional | Defaults to `true`. Set to `false` to disable pickup delay alerts |
| `ENABLE_PREPARING_ASSIGNED_ADMIN_ALERTS` | Optional | Defaults to `true`. Set to `false` to disable preparing assigned alerts |
| `ENABLE_PARCEL_WAITING_ADMIN_ALERTS` | Optional | Defaults to `true`. Set to `false` to disable parcel waiting alerts |

---

## Monitoring & Observability

- **Audience Diagnostics**: Inspect `getAdminAudienceDiagnostic()` or check backend logs:
  `[admin-recipients] using N id(s) from ADMIN_ORDER_ALERT_USER_IDS`
  `[admin-recipients] ignoring M invalid UUID(s)`
- **Dispatch Log Invariant**: Query table `notification_dispatch_log` to audit alert sends:
  ```sql
  SELECT dispatch_key, cohort, status, provider_response->>'total_sent' AS total_sent, created_at, updated_at
  FROM notification_dispatch_log
  WHERE cohort = 'admin'
  ORDER BY created_at DESC
  LIMIT 50;
  ```
- **Push Notification Audit**: Query table `push_notifications_log`:
  ```sql
  SELECT id, user_id, title, status, data->>'type' AS type, data->>'flow' AS flow, created_at
  FROM push_notifications_log
  WHERE data->>'type' = 'admin_order_alert'
  ORDER BY created_at DESC
  LIMIT 50;
  ```
