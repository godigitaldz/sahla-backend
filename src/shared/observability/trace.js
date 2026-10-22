import crypto from 'node:crypto';

export function createTraceId(seed) {
  if (seed && String(seed).trim()) return String(seed).trim();
  return crypto.randomUUID();
}

export function traceLogger(logger, traceId) {
  return {
    info: (msg, meta = {}) => logger.info?.(msg, { trace_id: traceId, ...meta }),
    warn: (msg, meta = {}) => logger.warn?.(msg, { trace_id: traceId, ...meta }),
    error: (msg, meta = {}) => logger.error?.(msg, { trace_id: traceId, ...meta }),
  };
}
