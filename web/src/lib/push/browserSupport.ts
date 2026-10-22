/** Browser capability detection for web order push. */

export type BrowserPushSupport =
  | { kind: 'supported' }
  | { kind: 'unsupported'; reason: 'insecure' | 'no_service_worker' | 'no_notifications' | 'no_push' | 'no_firebase_config' }
  | { kind: 'ios_home_screen_required' };

function isIosDevice(): boolean {
  if (typeof navigator === 'undefined') return false;
  return /iPad|iPhone|iPod/.test(navigator.userAgent) ||
    (navigator.platform === 'MacIntel' && navigator.maxTouchPoints > 1);
}

function isStandaloneDisplay(): boolean {
  if (typeof window === 'undefined') return false;
  const nav = navigator as Navigator & { standalone?: boolean };
  return window.matchMedia('(display-mode: standalone)').matches || nav.standalone === true;
}

export function detectBrowserPushSupport(): BrowserPushSupport {
  if (typeof window === 'undefined') {
    return { kind: 'unsupported', reason: 'insecure' };
  }

  if (!window.isSecureContext) {
    return { kind: 'unsupported', reason: 'insecure' };
  }

  const hasFirebaseConfig =
    Boolean(process.env.NEXT_PUBLIC_FIREBASE_API_KEY) &&
    Boolean(process.env.NEXT_PUBLIC_FIREBASE_PROJECT_ID) &&
    Boolean(process.env.NEXT_PUBLIC_FIREBASE_MESSAGING_SENDER_ID) &&
    Boolean(process.env.NEXT_PUBLIC_FIREBASE_APP_ID) &&
    Boolean(process.env.NEXT_PUBLIC_FIREBASE_VAPID_KEY);

  if (!hasFirebaseConfig) {
    return { kind: 'unsupported', reason: 'no_firebase_config' };
  }

  if (!('serviceWorker' in navigator)) {
    return { kind: 'unsupported', reason: 'no_service_worker' };
  }

  if (!('PushManager' in window) || typeof PushManager === 'undefined') {
    return { kind: 'unsupported', reason: 'no_push' };
  }

  if (!('Notification' in window)) {
    return { kind: 'unsupported', reason: 'no_notifications' };
  }

  if (isIosDevice() && !isStandaloneDisplay()) {
    return { kind: 'ios_home_screen_required' };
  }

  return { kind: 'supported' };
}

export function permissionState(): NotificationPermission | 'unsupported' {
  if (typeof window === 'undefined' || !('Notification' in window)) {
    return 'unsupported';
  }
  return Notification.permission;
}

export function userAgentFamily(): string {
  if (typeof navigator === 'undefined') return 'unknown';
  const ua = navigator.userAgent;
  if (/Edg\//.test(ua)) return 'edge';
  if (/Chrome\//.test(ua)) return 'chrome';
  if (/Safari\//.test(ua) && !/Chrome\//.test(ua)) return 'safari';
  if (/Firefox\//.test(ua)) return 'firefox';
  return 'other';
}

export function platformHint(): string {
  if (typeof navigator === 'undefined') return 'unknown';
  const ua = navigator.userAgent;
  if (/Android/.test(ua)) return 'android';
  if (/iPad|iPhone|iPod/.test(ua)) return 'ios';
  if (/Mac/.test(ua)) return 'macos';
  if (/Win/.test(ua)) return 'windows';
  return 'other';
}
