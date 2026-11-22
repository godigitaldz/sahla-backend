import express, { Router } from 'express';
import {
  isRateLimited,
  normalizeDownloadEvent,
  parseDownloadBody,
  storeDownloadEvent,
} from '../services/downloadTracking.js';

const router = Router();
const rawBody = express.raw({ type: ['application/json', 'text/plain'], limit: '4kb' });

function isSameOrigin(req) {
  const origin = String(req.get('origin') || '').trim();
  if (!origin) return true;
  const proto = String(req.get('x-forwarded-proto') || req.protocol || 'https').split(',')[0].trim();
  const host = String(req.get('x-forwarded-host') || req.get('host') || '').split(',')[0].trim();
  return origin === `${proto}://${host}`;
}

router.post('/download', (req, res, next) => {
  rawBody(req, res, (error) => error ? res.sendStatus(204) : next());
}, async (req, res) => {
  res.status(204);
  try {
    if (!isSameOrigin(req) || isRateLimited(req.ip)) return res.end();
    const body = parseDownloadBody(req.body);
    const row = normalizeDownloadEvent(body, req.get('user-agent') || '');
    if (!row) return res.end();
    storeDownloadEvent(row).catch((error) => {
      // No request body, IP, or raw user-agent is logged.
      console.error('[download-tracking] event insert failed:', error?.message || 'unknown_error');
    });
  } catch (error) {
    // No request body, IP, or raw user-agent is logged.
    console.error('[download-tracking] event insert failed:', error?.message || 'unknown_error');
  }
  return res.end();
});

export default router;
