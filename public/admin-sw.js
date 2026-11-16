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
  const tag = data.tag || `admin-alert-${data.order_id || Date.now()}`;

  const isCritical = severity === 'critical';

  const options = {
    body,
    icon: '/images/sahla-logo.png',
    badge: '/images/sahla-logo.png',
    tag,
    renotify: true,
    requireInteraction: isCritical,
    silent: false,
    vibrate: isCritical ? [250, 100, 250, 100, 500] : [200, 100, 200],
    data: {
      clickUrl,
      orderId: data.order_id || null,
      alertId: data.alert_id || null,
      severity,
    },
    actions: [
      { action: 'open', title: '👁️ Open Alert' },
      { action: 'ack', title: '✋ Acknowledge' },
    ],
  };

  event.waitUntil(self.registration.showNotification(title, options));
});

self.addEventListener('notificationclick', (event) => {
  event.notification.close();

  const data = event.notification.data || {};
  const targetUrl = data.clickUrl || '/performance?view=alerts';

  // Handle direct in-notification acknowledgement
  if (event.action === 'ack' && data.alertId) {
    event.waitUntil(
      fetch(`/api/performance/alerts/${encodeURIComponent(data.alertId)}/acknowledge`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ operator_name: 'Notification Action' }),
      }).catch(() => {})
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
