/**
 * Sahla Staff Service Worker
 * Scope: /staff/
 *
 * Implements Web Push notifications and offline fallback without caching
 * authenticated or dynamic order/menu API payloads.
 */

const CACHE_NAME = 'sahla-staff-shell-v1';
const SHELL_ASSETS = ['/staff/', '/favicon.ico', '/staff-manifest.webmanifest'];

self.addEventListener('install', (event) => {
  event.waitUntil(
    caches.open(CACHE_NAME).then((cache) => cache.addAll(SHELL_ASSETS)).then(() => self.skipWaiting()),
  );
});

self.addEventListener('activate', (event) => {
  event.waitUntil(
    caches
      .keys()
      .then((keys) =>
        Promise.all(
          keys.map((k) => {
            if (k !== CACHE_NAME && k.startsWith('sahla-staff-')) {
              return caches.delete(k);
            }
          }),
        ),
      )
      .then(() => self.clients.claim()),
  );
});

self.addEventListener('fetch', (event) => {
  const url = new URL(event.request.url);

  // Bypass cache for all staff API requests, Auth calls, and dynamic data
  if (url.pathname.includes('/api/') || event.request.method !== 'GET') {
    return;
  }

  // Network-first for staff navigation, fallback to shell
  event.respondWith(
    fetch(event.request).catch(async () => {
      const cached = await caches.match(event.request);
      if (cached) return cached;
      if (event.request.mode === 'navigate') {
        return caches.match('/staff/');
      }
      return new Response('Offline', { status: 503, statusText: 'Service Unavailable' });
    }),
  );
});

// Push notification handling
self.addEventListener('push', (event) => {
  let payload = {
    title: 'طلب جديد — ساهلة',
    body: 'وصلك طلب جديد في المطعم',
    data: { url: '/staff/' },
  };

  if (event.data) {
    try {
      payload = event.data.json();
    } catch {
      payload.body = event.data.text();
    }
  }

  const options = {
    body: payload.body || 'تنبيه جديد من ساهلة',
    icon: '/favicon.ico',
    badge: '/favicon.ico',
    vibrate: [500, 200, 500, 200, 500, 200, 500],
    data: payload.data || { url: '/staff/' },
    tag: payload.data?.order_id || 'staff-order-alert',
    renotify: true,
    requireInteraction: true,
    silent: false,
  };

  event.waitUntil(self.registration.showNotification(payload.title || 'ساهلة — تنبيه المطعم', options));
});

self.addEventListener('notificationclick', (event) => {
  event.notification.close();
  const targetUrl = event.notification.data?.url || '/staff/';

  event.waitUntil(
    clients.matchAll({ type: 'window', includeUncontrolled: true }).then((clientList) => {
      for (const client of clientList) {
        if (client.url.includes('/staff') && 'focus' in client) {
          return client.focus();
        }
      }
      if (clients.openWindow) {
        return clients.openWindow(targetUrl);
      }
    }),
  );
});

self.addEventListener('pushsubscriptionchange', (event) => {
  event.waitUntil(
    self.registration.pushManager
      .subscribe(event.oldSubscription?.options)
      .then((newSub) => {
        // Send updated subscription to staff API
        return fetch('/staff/api/push/subscribe', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify(newSub),
        });
      })
      .catch((err) => {
        console.error('[staff-sw] pushsubscriptionchange failed:', err);
      }),
  );
});
