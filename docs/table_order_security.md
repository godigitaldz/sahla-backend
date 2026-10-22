# Table Order Security Policy

## Presence model

- Printed QR: `https://sahla-delivery.com/t/{opaque_uuid}` — identifies table only.
- Rotating venue code (6 digits, ~5 min window): displayed in-restaurant only.
- Both required to mint a session.

## Session cookies

| Cookie | Flags | Path |
|--------|-------|------|
| `sahla_table_session` | HttpOnly; Secure; SameSite=Strict | `/api/public/table` |
| `sahla_table_csrf` | Secure; SameSite=Strict (not HttpOnly) | `/` |

POST mutations require header `X-Table-CSRF` matching `sahla_table_csrf`.

## Origin validation

Reject POST when `Origin` or `Referer` is present and not in allowlist:
- `https://sahla-delivery.com`
- `http://localhost:3000` (dev)

## Logging

Never log raw `table_code`, venue codes, or session tokens.

## QR page

- `Referrer-Policy: no-referrer` on `/t/*`
- No third-party scripts or analytics on scan page

## Rate limits (Upstash)

| Key | Limit |
|-----|-------|
| `table:scan:ip:{ip}` | 30 / 15 min |
| `table:venue:{tableHash}:ip:{ip}` | 5 / window; lockout 15 min |
| `table:order:phone:{phone}` | 8 / hour |
| `table:order:session:{sessionId}` | 3 / 10 min |

## Admin

Table CRUD requires Supabase JWT + `user_profiles.role IN ('admin','super_admin')`.
Performance dashboard password alone is insufficient for mutations.
