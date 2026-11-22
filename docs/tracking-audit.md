# Download funnel implementation audit

## Existing gateway and redirect flow

- `public/download.js` owns rendering and routing behavior for `/open`, `/download`, and `/#download`; `public/config.js` owns store URLs and deep-link settings. The existing `track(event, props)` hook forwards to configured browser analytics providers and logs diagnostic events. Before this feature it had no first-party backend endpoint.
- Existing hook calls covered page view, in-app detection, app-open taps/timeouts, store taps, escape taps, and copy-link clicks. Missing canonical events included platform detection, automatic store redirects, likely app-open heuristics, and a stable server-side funnel event model. The implementation maps existing hooks to canonical event names and adds passive signals at existing lifecycle callbacks.
- `public/open.html` and `public/download.html` load root config and gateway assets. `src/index.js` serves `public/` through Express static middleware, has explicit `/open*` and `/download*` HTML routes, mounts API routes, then applies its 404 handler. The Next.js routes at `web/src/app/open/route.ts` and `web/src/app/download/route.ts` also serve the gateway HTML. `scripts/sync-public.js` mirrors `public/` to `web/public/`; `scripts/stamp-version.js` stamps asset query strings and the footer build hash.
- Redirect behavior was treated as immutable. Tracking calls are fire-and-forget and catch their own errors; no redirect condition, delay, destination, scheme, intent, banner, or store URL was intentionally changed for funnel tracking.

## Performance dashboard

- The Performance screen is the static Arabic RTL page `public/performance.html`, served by `src/index.js` at `/performance`. Its UI and tabs are implemented in that HTML with inline CSS and JavaScript; translations live in `public/performance-i18n.js` and already support Arabic, French, and English.
- Existing data requests use the shared `/api/performance` fetch helper and `perf_auth` HttpOnly session cookie. `src/routes/performanceDashboard.js` implements `requirePerformanceAuth`; the new stats endpoint uses the same middleware. Existing dashboard refresh intervals are 15/30 seconds and pause while hidden. The download tab follows the active-tab 30-second refresh interval.
- Database access uses `supabaseAdmin` from `src/config/supabase.js`, which uses the service-role key on the server. Migrations are in `supabase/migrations/`; conventions include idempotent DDL, RLS, revoking public/anon/authenticated access, and granting service-role operations.

## Event and privacy decisions

- Funnel events are defined in the README and stored in `public.download_events`. Page views are unique by session through a partial unique index. SQL aggregates unique sessions for KPIs and breakdowns; bots are excluded by default. The stats RPC buckets page-view sessions by the requested IANA timezone, defaulting to `Africa/Algiers`.
- The client stores only a random session ID in `sessionStorage` with an in-memory fallback. There are no cookies or fingerprinting. The server checks the IP transiently for rate limiting and checks the user-agent transiently for bot classification; neither is persisted. `ua_hash` and `country` remain null. No existing Do Not Track behavior was found, so DNT is not newly treated as an opt-out.
- “Reached store” means a store redirect or store-link tap, not an install. `app_opened_likely` is a browser visibility/page-hide heuristic. Install and actual app-open attribution require later store campaign or native-app data (`TODO_STORE_CAMPAIGN_ATTRIBUTION`).

## Routing and deployment notes

- `/api/track/download` is registered before the shared JSON parser, general API rate limiter, static assets, `/open*`/`/download*` HTML routes, and final 404 handler. It has a route-specific 4 KB parser and returns 204 for invalid, oversized, cross-origin, rate-limited, and insertion-failure requests. Global CORS remains in place; the ingest handler also checks same-origin `Origin` values.
- Performance stats are mounted inside the existing authenticated `/api/performance` router. The migration must be applied before the endpoint can return data. Apply `supabase/migrations/20261122120000_download_funnel_tracking.sql` before deploying the code.
- `public/` is the Express static source in this deployment. The web tree is kept in sync with `npm run sync:public` so Next.js-served gateway copies match.

## Validation scope

`scripts/test-download-tracking.js` runs a local stub endpoint and Chrome CDP checks across six simulated user-agent families and four routes, with endpoint success/failure modes. `src/routes/downloadTracking.test.js` checks route validation, body limits, bot flags, rate limits, and Performance auth using local Supabase method stubs. `scripts/test-download-tracking-stats.sql` contains seeded database assertions for unique-session funnel math and Algiers day bucketing; run it in the Supabase SQL editor after the migration. Headless browser tests do not substitute for physical-device deep-link checks.
