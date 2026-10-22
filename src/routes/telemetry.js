import { Router } from 'express';

import { telemetryLimiter } from '../middleware/rateLimiter.js';
import { ingestTelemetryBatch } from '../services/telemetryService.js';

const router = Router();

function telemetrySecret() {
  return String(process.env.TELEMETRY_INGEST_SECRET || '').trim();
}

function requireTelemetryAuth(req, res, next) {
  const secret = telemetrySecret();
  if (!secret) return next();
  const header = String(req.headers['x-telemetry-secret'] || '').trim();
  if (!header || header !== secret) {
    return res.status(401).json({ success: false, error: 'unauthorized' });
  }
  return next();
}

router.post('/events', telemetryLimiter, requireTelemetryAuth, async (req, res) => {
  try {
    const events = req.body?.events ?? req.body;
    const result = await ingestTelemetryBatch(events);
    return res.json({ success: true, ...result });
  } catch (e) {
    const message = e.message || 'ingest_failed';
    const status = ['events_required', 'batch_too_large', 'invalid_event_type', 'device_id_required', 'invalid_occurred_at', 'invalid_payload', 'payload_too_large'].includes(message)
      ? 400
      : 500;
    if (status === 500) {
      console.error('telemetry /events', e);
    }
    return res.status(status).json({ success: false, error: message });
  }
});

export default router;
