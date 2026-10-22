import { describe, expect, it, beforeEach, afterEach, vi } from 'vitest';
import {
  clearLocalRegistration,
  readLocalRegistration,
  registrationStorageKey,
  storeLocalRegistration,
} from '@/lib/push/firebaseWeb';

function mockSessionStorage() {
  const store = new Map<string, string>();
  const sessionStorageMock = {
    getItem: (key: string) => store.get(key) ?? null,
    setItem: (key: string, value: string) => {
      store.set(key, value);
    },
    removeItem: (key: string) => {
      store.delete(key);
    },
    clear: () => store.clear(),
  };
  vi.stubGlobal('sessionStorage', sessionStorageMock);
  return store;
}

describe('firebaseWeb registration scope', () => {
  beforeEach(() => {
    mockSessionStorage();
  });

  afterEach(() => {
    vi.unstubAllGlobals();
  });

  it('scopes storage by tracking token prefix', () => {
    const tokenA = 'abc1234567890123456789012345678901234567890';
    const tokenB = 'xyz9876543210987654321098765432109876543210';

    storeLocalRegistration(tokenA, 'reg-value-a');
    storeLocalRegistration(tokenB, 'reg-value-b');

    expect(readLocalRegistration(tokenA)).toBe('reg-value-a');
    expect(readLocalRegistration(tokenB)).toBe('reg-value-b');
    expect(registrationStorageKey(tokenA)).not.toBe(registrationStorageKey(tokenB));
  });

  it('clearLocalRegistration only removes scoped entry', () => {
    const tokenA = 'abc1234567890123456789012345678901234567890';
    const tokenB = 'xyz9876543210987654321098765432109876543210';
    storeLocalRegistration(tokenA, 'a');
    storeLocalRegistration(tokenB, 'b');

    clearLocalRegistration(tokenA);
    expect(readLocalRegistration(tokenA)).toBeNull();
    expect(readLocalRegistration(tokenB)).toBe('b');
  });
});
