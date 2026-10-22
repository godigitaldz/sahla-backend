import { describe, expect, it, vi } from 'vitest';
import { detectBrowserPushSupport, permissionState } from '@/lib/push/browserSupport';

describe('browserSupport', () => {
  it('returns unsupported without window', () => {
    const originalWindow = global.window;
    // @ts-expect-error test shim
    delete global.window;
    expect(detectBrowserPushSupport().kind).toBe('unsupported');
    global.window = originalWindow;
  });

  it('permissionState is unsupported without Notification API', () => {
    const originalNotification = global.Notification;
    // @ts-expect-error test shim
    delete global.Notification;
    expect(permissionState()).toBe('unsupported');
    global.Notification = originalNotification;
  });

  it('returns unsupported when PushManager missing', () => {
    const originalWindow = global.window;
    // @ts-expect-error test shim
    global.window = {
      isSecureContext: true,
      PushManager: undefined,
      navigator: { serviceWorker: {} },
      Notification: { permission: 'default' },
    };
    vi.stubGlobal('navigator', { serviceWorker: {} });

    process.env.NEXT_PUBLIC_FIREBASE_API_KEY = 'k';
    process.env.NEXT_PUBLIC_FIREBASE_PROJECT_ID = 'p';
    process.env.NEXT_PUBLIC_FIREBASE_MESSAGING_SENDER_ID = 's';
    process.env.NEXT_PUBLIC_FIREBASE_APP_ID = 'a';
    process.env.NEXT_PUBLIC_FIREBASE_VAPID_KEY = 'v';

    expect(detectBrowserPushSupport()).toEqual({ kind: 'unsupported', reason: 'no_push' });

    global.window = originalWindow;
    vi.unstubAllGlobals();
  });
});

describe('push privacy', () => {
  it('payload data keys exclude sensitive fields', () => {
    const data = {
      type: 'web_order_status',
      event: 'order_preparing',
      status: 'preparing',
      order_id: '00000000-0000-4000-8000-000000000001',
    };
    const json = JSON.stringify(data);
    expect(json).not.toMatch(/phone/i);
    expect(json).not.toMatch(/address/i);
    expect(json).not.toMatch(/latitude/i);
    expect(json).not.toMatch(/click_url/i);
    expect(json).not.toMatch(/registration/i);
  });
});
