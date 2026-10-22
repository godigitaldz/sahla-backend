/* eslint-disable no-undef */
/* Generated from firebase-messaging-sw.template.js — do not edit by hand. */
importScripts('https://www.gstatic.com/firebasejs/11.2.0/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/11.2.0/firebase-messaging-compat.js');

firebase.initializeApp({"apiKey":"","authDomain":"","projectId":"","storageBucket":"","messagingSenderId":"","appId":""});
const messaging = firebase.messaging();

function normalizePathname(urlString) {
  try {
    return new URL(urlString).pathname.replace(/\/+$/, '') || '/';
  } catch (_e) {
    return '';
  }
}

function urlsMatch(clientUrl, targetLink) {
  try {
    const client = new URL(clientUrl);
    const target = new URL(targetLink, client.origin);
    return (
      client.origin === target.origin &&
      normalizePathname(client.href) === normalizePathname(target.href)
    );
  } catch (_e) {
    return false;
  }
}

function sameOrigin(clientUrl, targetLink) {
  try {
    const client = new URL(clientUrl);
    const target = new URL(targetLink, client.origin);
    return client.origin === target.origin;
  } catch (_e) {
    return false;
  }
}

messaging.onBackgroundMessage(function (payload) {
  const title = payload.notification?.title || payload.data?.title || 'تحديث الطلب';
  const body = payload.notification?.body || payload.data?.body || 'تغيّرت حالة طلبك.';
  const link =
    payload.fcmOptions?.link ||
    payload.data?.link ||
    payload.data?.click_link ||
    '/';

  self.registration.showNotification(title, {
    body,
    data: { link },
  });
});

self.addEventListener('notificationclick', function (event) {
  event.notification.close();
  const link = event.notification.data?.link || '/';
  event.waitUntil(
    clients.matchAll({ type: 'window', includeUncontrolled: true }).then(async function (clientList) {
      for (const client of clientList) {
        if (client.url && urlsMatch(client.url, link) && 'focus' in client) {
          return client.focus();
        }
      }
      for (const client of clientList) {
        if (client.url && sameOrigin(client.url, link) && 'navigate' in client) {
          await client.navigate(link);
          if ('focus' in client) return client.focus();
        }
      }
      if (clients.openWindow) {
        return clients.openWindow(link);
      }
    }),
  );
});
