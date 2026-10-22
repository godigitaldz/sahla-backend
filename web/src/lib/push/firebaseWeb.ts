'use client';

import { initializeApp, getApps, type FirebaseApp } from 'firebase/app';
import {
  getMessaging,
  getToken,
  onMessage,
  type Messaging,
  isSupported,
} from 'firebase/messaging';

export type FcmRegistrationResult =
  | { ok: true; registration_value: string; registration_kind: 'legacy_token' | 'fid' }
  | { ok: false; reason: string };

function firebaseConfig() {
  return {
    apiKey: process.env.NEXT_PUBLIC_FIREBASE_API_KEY,
    authDomain: process.env.NEXT_PUBLIC_FIREBASE_AUTH_DOMAIN,
    projectId: process.env.NEXT_PUBLIC_FIREBASE_PROJECT_ID,
    storageBucket: process.env.NEXT_PUBLIC_FIREBASE_STORAGE_BUCKET,
    messagingSenderId: process.env.NEXT_PUBLIC_FIREBASE_MESSAGING_SENDER_ID,
    appId: process.env.NEXT_PUBLIC_FIREBASE_APP_ID,
  };
}

function getOrInitApp(): FirebaseApp {
  const existing = getApps();
  if (existing.length > 0) return existing[0]!;
  return initializeApp(firebaseConfig());
}

async function ensureServiceWorker(): Promise<ServiceWorkerRegistration> {
  const registration = await navigator.serviceWorker.register('/firebase-messaging-sw.js', {
    scope: '/',
  });
  await navigator.serviceWorker.ready;
  return registration;
}

/**
 * Register for FCM web push.
 * FCM v1 send uses the registration token (legacy_token path) in message.token.
 * Firebase docs prefer register()+onRegistered(); getToken() remains the practical
 * send target until FID-native FCM send is verified end-to-end.
 */
export async function registerForWebOrderPush(): Promise<FcmRegistrationResult> {
  const supported = await isSupported();
  if (!supported) {
    return { ok: false, reason: 'messaging_not_supported' };
  }

  const vapidKey = process.env.NEXT_PUBLIC_FIREBASE_VAPID_KEY?.trim();
  if (!vapidKey) {
    return { ok: false, reason: 'missing_vapid_key' };
  }

  const permission = await Notification.requestPermission();
  if (permission !== 'granted') {
    return { ok: false, reason: permission === 'denied' ? 'permission_denied' : 'permission_dismissed' };
  }

  const swRegistration = await ensureServiceWorker();
  const app = getOrInitApp();
  const messaging: Messaging = getMessaging(app);

  const token = await getToken(messaging, {
    vapidKey,
    serviceWorkerRegistration: swRegistration,
  });

  if (!token) {
    return { ok: false, reason: 'empty_token' };
  }

  return {
    ok: true,
    registration_value: token,
    registration_kind: 'legacy_token',
  };
}

export async function listenForForegroundMessages(
  onPayload: () => void,
): Promise<(() => void) | null> {
  const supported = await isSupported();
  if (!supported) return null;

  const app = getOrInitApp();
  const messaging = getMessaging(app);
  return onMessage(messaging, () => {
    onPayload();
  });
}

export async function savePushSubscription(params: {
  token: string;
  registration: FcmRegistrationResult & { ok: true };
  permission_state: string;
  user_agent_family: string;
  platform_hint: string;
}): Promise<{ ok: true } | { ok: false; reason: string }> {
  const response = await fetch(
    `/api/public/orders/track/${encodeURIComponent(params.token)}/notifications`,
    {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        provider: 'fcm_web',
        registration_kind: params.registration.registration_kind,
        registration_value: params.registration.registration_value,
        permission_state: params.permission_state,
        user_agent_family: params.user_agent_family,
        platform_hint: params.platform_hint,
      }),
    },
  );

  if (!response.ok) {
    return { ok: false, reason: 'save_failed' };
  }
  return { ok: true };
}

export async function revokePushSubscription(params: {
  token: string;
  registration_value: string;
}): Promise<boolean> {
  const response = await fetch(
    `/api/public/orders/track/${encodeURIComponent(params.token)}/notifications`,
    {
      method: 'DELETE',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ registration_value: params.registration_value }),
    },
  );
  return response.ok;
}

const STORAGE_PREFIX = 'sahla_web_push_reg:';

export function registrationStorageKey(token: string): string {
  const prefix = token.slice(0, 8);
  return `${STORAGE_PREFIX}${prefix}`;
}

export function storeLocalRegistration(token: string, value: string) {
  try {
    sessionStorage.setItem(registrationStorageKey(token), value);
  } catch {
    /* ignore */
  }
}

export function readLocalRegistration(token: string): string | null {
  try {
    return sessionStorage.getItem(registrationStorageKey(token));
  } catch {
    return null;
  }
}

export function clearLocalRegistration(token: string) {
  try {
    sessionStorage.removeItem(registrationStorageKey(token));
  } catch {
    /* ignore */
  }
}
