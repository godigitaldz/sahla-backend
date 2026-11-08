# Sahla Delivery Working Hours - Cloudflare Cron Worker

Automated Cloudflare Cron Worker that continuously enforces delivery personnel working hours (11:00 to 22:00 Africa/Algiers daily) with zero client app modifications.

---

## How It Works
1. **Cloudflare Cron Trigger**: Fires every 5 minutes (`*/5 * * * *`).
2. **Backend Authentication**: Sends an authenticated request to `sahla-backend`:
   `POST https://sahla-delivery.com/api/internal/delivery-personnel/sync-working-hours` with `Authorization: Bearer <CRON_SECRET>`.
3. **Outside Shift (e.g. 22:00 -> 11:00 DZ time)**:
   - Sets couriers' `is_available = false`.
   - Records their IDs in `system_config` under `delivery_personnel_auto_closed_ids`.
4. **Inside Shift (e.g. 11:00 -> 22:00 DZ time)**:
   - Restores `is_available = true` **only** for couriers who were auto-closed by the schedule.
   - Preserves couriers who were manually set unavailable (off duty, illness, breaks).
   - Never re-opens blocked couriers.

---

## Deployment Instructions

### Option 1: Via Cloudflare Dashboard (Quickest & No CLI needed)

1. Go to the [Cloudflare Dashboard](https://dash.cloudflare.com/) → **Workers & Pages** → **Create application** → **Create Worker**.
2. Name it `sahla-delivery-working-hours` and click **Deploy**.
3. Click **Edit code** and paste the entire contents of [`index.js`](./index.js), then click **Save and deploy**.
4. Go to worker **Settings** → **Variables and Secrets**:
   - Add Secret: `CRON_SECRET` with your backend's `CRON_SECRET` value.
   - Add Variable: `BACKEND_URL` with `https://sahla-delivery.com` (or your backend URL).
5. Go to worker **Settings** → **Triggers** → **Cron Triggers**:
   - Click **Add Cron Trigger**.
   - Set Cron Expression to `*/5 * * * *` (every 5 minutes).
   - Click **Add trigger**.

---

### Option 2: Via Wrangler CLI

1. Open a terminal in this directory:
   ```bash
   cd cloudflare/delivery-working-hours-worker
   ```
2. Log in to Cloudflare (if not already logged in):
   ```bash
   npx wrangler login
   ```
3. Set your `CRON_SECRET`:
   ```bash
   npx wrangler secret put CRON_SECRET
   ```
   *(Paste your backend's `CRON_SECRET` when prompted)*
4. Deploy the worker:
   ```bash
   npx wrangler deploy
   ```

---

## Manual Verification & Endpoints

- **Health Check**:
  `GET https://sahla-delivery-working-hours.<your-subdomain>.workers.dev/health`
- **Manual Sync Trigger**:
  `GET https://sahla-delivery-working-hours.<your-subdomain>.workers.dev/sync`
- **Live Logs**:
  `npx wrangler tail`
