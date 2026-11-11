import { Client } from '@upstash/qstash';

const BACKEND_URL = 'https://sahla-backend.vercel.app';
const TARGET_DESTINATION = `${BACKEND_URL}/api/internal/pending-orders-poll`;

export async function ensureQstashAutonomousCron() {
  const token = process.env.QSTASH_TOKEN;
  const cronSecret = process.env.CRON_SECRET;

  if (!token || !cronSecret) {
    console.warn('[QStash Cron] Missing QSTASH_TOKEN or CRON_SECRET, skipping schedule verification');
    return { success: false, reason: 'missing_env' };
  }

  const client = new Client({ token });

  try {
    const schedules = await client.schedules.list();
    const existing = (schedules || []).find((s) => s.destination === TARGET_DESTINATION);

    if (existing) {
      console.log(`[QStash Cron] Active schedule found: ${existing.scheduleId} (cron: ${existing.cron})`);
      return { success: true, scheduleId: existing.scheduleId, created: false };
    }

    console.log(`[QStash Cron] No active schedule found for ${TARGET_DESTINATION}. Creating 1-minute schedule...`);
    const created = await client.schedules.create({
      destination: TARGET_DESTINATION,
      cron: '* * * * *',
      method: 'GET',
      headers: {
        Authorization: `Bearer ${cronSecret}`,
      },
      retries: 2,
    });

    console.log(`[QStash Cron] Successfully created recurring schedule: ${created.scheduleId}`);
    return { success: true, scheduleId: created.scheduleId, created: true };
  } catch (err) {
    console.error('[QStash Cron] Failed to ensure QStash schedule:', err.message);
    return { success: false, error: err.message };
  }
}

// Self-execute if run directly
if (process.argv[1] && process.argv[1].endsWith('ensure_autonomous_qstash_cron.js')) {
  ensureQstashAutonomousCron().then(res => {
    console.log('Result:', res);
    process.exit(0);
  });
}
