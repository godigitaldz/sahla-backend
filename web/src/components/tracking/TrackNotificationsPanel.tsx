'use client';

import { useCallback, useEffect, useState } from 'react';
import { ar } from '@/lib/i18n/ar';
import {
  detectBrowserPushSupport,
  permissionState,
  platformHint,
  userAgentFamily,
} from '@/lib/push/browserSupport';
import {
  clearLocalRegistration,
  listenForForegroundMessages,
  readLocalRegistration,
  registerForWebOrderPush,
  revokePushSubscription,
  savePushSubscription,
  storeLocalRegistration,
} from '@/lib/push/firebaseWeb';

type UiState =
  | 'hidden'
  | 'unsupported'
  | 'ios_home_screen'
  | 'not_requested'
  | 'denied'
  | 'registering'
  | 'enabled'
  | 'save_failed'
  | 'disabled';

type Props = {
  pushEnabled: boolean;
  token: string;
  orderLoaded: boolean;
  onForegroundMessage?: () => void;
};

export function TrackNotificationsPanel({
  pushEnabled,
  token,
  orderLoaded,
  onForegroundMessage,
}: Props) {
  const [uiState, setUiState] = useState<UiState>('hidden');

  useEffect(() => {
    if (!pushEnabled || !orderLoaded) {
      const t = window.setTimeout(() => setUiState('hidden'), 0);
      return () => window.clearTimeout(t);
    }

    const t = window.setTimeout(() => {
      const support = detectBrowserPushSupport();
      if (support.kind === 'ios_home_screen_required') {
        setUiState('ios_home_screen');
        return;
      }
      if (support.kind === 'unsupported') {
        setUiState('unsupported');
        return;
      }

      const perm = permissionState();
      const stored = readLocalRegistration(token);
      if (stored) {
        setUiState('enabled');
        return;
      }
      if (perm === 'denied') {
        setUiState('denied');
        return;
      }
      setUiState('not_requested');
    }, 0);

    return () => window.clearTimeout(t);
  }, [pushEnabled, orderLoaded, token]);

  useEffect(() => {
    if (!pushEnabled || !orderLoaded) return;
    let unsubscribe: (() => void) | null = null;
    void listenForForegroundMessages(() => {
      onForegroundMessage?.();
    }).then((fn) => {
      unsubscribe = fn;
    });
    return () => {
      unsubscribe?.();
    };
  }, [pushEnabled, orderLoaded, onForegroundMessage]);

  const handleEnable = useCallback(async () => {
    setUiState('registering');
    const registration = await registerForWebOrderPush();
    if (!registration.ok) {
      if (registration.reason === 'permission_denied') {
        setUiState('denied');
      } else {
        setUiState('save_failed');
      }
      return;
    }

    const saved = await savePushSubscription({
      token,
      registration,
      permission_state: permissionState(),
      user_agent_family: userAgentFamily(),
      platform_hint: platformHint(),
    });

    if (!saved.ok) {
      setUiState('save_failed');
      return;
    }

    storeLocalRegistration(token, registration.registration_value);
    setUiState('enabled');
  }, [token]);

  const handleDisable = useCallback(async () => {
    const stored = readLocalRegistration(token);
    if (stored) {
      await revokePushSubscription({ token, registration_value: stored });
    }
    clearLocalRegistration(token);
    setUiState('disabled');
  }, [token]);

  if (uiState === 'hidden') return null;

  return (
    <section className="mt-4 rounded-2xl border border-orange-100 bg-orange-50/60 p-4 text-sm text-gray-800">
      <h2 className="font-bold text-gray-900">{ar.trackNotifyTitle}</h2>

      {uiState === 'unsupported' && (
        <p className="mt-2 text-gray-600">{ar.trackNotifyUnsupported}</p>
      )}
      {uiState === 'ios_home_screen' && (
        <p className="mt-2 text-gray-600">{ar.trackNotifyIosHomeScreen}</p>
      )}
      {uiState === 'not_requested' && (
        <>
          <p className="mt-2 text-gray-600">{ar.trackNotifyPrompt}</p>
          <button
            type="button"
            onClick={() => void handleEnable()}
            className="mt-3 w-full rounded-full bg-orange-500 px-4 py-2.5 text-sm font-semibold text-white"
          >
            {ar.trackNotifyEnable}
          </button>
        </>
      )}
      {uiState === 'registering' && (
        <p className="mt-2 text-gray-600">{ar.trackNotifyRegistering}</p>
      )}
      {uiState === 'denied' && (
        <p className="mt-2 text-gray-600">{ar.trackNotifyDenied}</p>
      )}
      {uiState === 'enabled' && (
        <>
          <p className="mt-2 text-green-700">{ar.trackNotifyEnabled}</p>
          <button
            type="button"
            onClick={() => void handleDisable()}
            className="mt-3 text-xs font-semibold text-gray-500 underline"
          >
            {ar.trackNotifyDisable}
          </button>
        </>
      )}
      {uiState === 'save_failed' && (
        <>
          <p className="mt-2 text-red-600">{ar.trackNotifySaveFailed}</p>
          <button
            type="button"
            onClick={() => void handleEnable()}
            className="mt-3 w-full rounded-full bg-orange-500 px-4 py-2.5 text-sm font-semibold text-white"
          >
            {ar.trackNotifyRetry}
          </button>
        </>
      )}
      {uiState === 'disabled' && (
        <p className="mt-2 text-gray-600">{ar.trackNotifyDisabled}</p>
      )}
    </section>
  );
}
