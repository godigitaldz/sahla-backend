/**
 * Sahla Operations Cockpit — Admin Service Worker
 * Handles Web Push notifications, desktop notification banners, and click routing.
 */

self.addEventListener('install', (event) => {
  self.skipWaiting();
});

self.addEventListener('activate', (event) => {
  event.waitUntil(self.clients.claim());
});

self.addEventListener('push', (event) => {
  if (!event.data) return;

  let payload = {};
  try {
    payload = event.data.json();
  } catch (_) {
    payload = {
      notification: {
        title: '⚠️ Sahla Admin Alert',
        body: event.data.text(),
      },
    };
  }

  const notification = payload.notification || {};
  const data = payload.data || {};

  const title = notification.title || data.title || payload.title || '⚠️ Sahla Alert';
  const body = notification.body || data.body || payload.body || 'Operational notification requires attention.';
  const clickUrl = data.click_url || data.click_action || '/performance?view=alerts';
  const severity = data.severity || 'critical';

  // Stable incident tag: derived from business incident identity, never timestamps
  const incidentIdentity = data.incident_key || (data.alert_type ? `${data.alert_type}:${data.order_id || data.task_id || 'incident'}` : null);
  const tag = data.tag || (incidentIdentity ? `admin-alert-${incidentIdentity}` : `admin-alert-${data.order_id || 'general'}`);

  const isCritical = severity === 'critical';
  const isInitial = data.is_new === true || data.is_initial === true;

  const options = {
    body,
    icon: '/sahla-logo-circle.png',
    badge: '/sahla-logo-circle.png',
    tag,
    // Stable tag replacement: do not re-sound if updating an existing incident
    renotify: isInitial,
    requireInteraction: isCritical,
    silent: false,
    vibrate: isCritical ? [250, 100, 250, 100, 500] : [200, 100, 200],
    data: {
      clickUrl,
      orderId: data.order_id || null,
      alertId: data.alert_id || null,
      incidentKey: data.incident_key || null,
      alertType: data.alert_type || null,
      severity,
    },
    actions: [
      { action: 'open', title: '👁️ Open Alert' },
      { action: 'ack', title: '✋ Acknowledge' },
    ],
  };

  event.waitUntil(self.registration.showNotification(title, options));
});

self.addEventListener('message', (event) => {
  if (event.data && event.data.type === 'SHOW_NOTIFICATION') {
    const { title, options } = event.data;
    event.waitUntil(self.registration.showNotification(title, options));
  }
});

self.addEventListener('notificationclick', (event) => {
  event.notification.close();

  const data = event.notification.data || {};
  const targetUrl = data.clickUrl || '/performance?view=alerts';
  const targetAckId = data.alertId || data.orderId;

  // Handle direct in-notification acknowledgement with credentials
  if (event.action === 'ack' && targetAckId) {
    event.waitUntil(
      fetch(`/api/performance/alerts/${encodeURIComponent(targetAckId)}/acknowledge`, {
        method: 'POST',
        credentials: 'include',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          operator_name: 'Notification Action',
          incident_key: data.incidentKey || null,
          alert_type: data.alertType || null,
        }),
      }).then(async (res) => {
        if (!res.ok) {
          console.error('[admin-sw] notification ack rejected by server status:', res.status);
        }
      }).catch((err) => {
        console.error('[admin-sw] notification ack network error:', err);
      })
    );
    return;
  }

  // Navigate or focus existing performance window
  event.waitUntil(
    self.clients.matchAll({ type: 'window', includeUncontrolled: true }).then(async (clientList) => {
      for (const client of clientList) {
        if (client.url && client.url.includes('/performance') && 'focus' in client) {
          if ('navigate' in client) {
            await client.navigate(targetUrl);
          }
          return client.focus();
        }
      }
      if (self.clients.openWindow) {
        return self.clients.openWindow(targetUrl);
      }
    })
  );
});
