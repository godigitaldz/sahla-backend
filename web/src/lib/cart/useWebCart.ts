'use client';

import { useCallback, useEffect, useMemo, useState } from 'react';

export type WebCartLine = {
  id: string;
  menu_item_id: string;
  name: string;
  image?: string | null;
  quantity: number;
  unit_price: number;
  total_price: number;
  pricing_size?: string | null;
  variant_name?: string | null;
  supplement_names?: string[];
  special_instructions?: string | null;
};

export type WebCartState = {
  restaurantId: string;
  restaurantSlug: string;
  restaurantName: string;
  items: WebCartLine[];
};

const STORAGE_PREFIX = 'sahla_web_cart:';

function storageKey(slug: string) {
  return `${STORAGE_PREFIX}${slug}`;
}

export function useWebCart(slug: string) {
  const [cart, setCart] = useState<WebCartState | null>(null);

  useEffect(() => {
    if (!slug) return;
    try {
      const raw = localStorage.getItem(storageKey(slug));
      if (raw) setCart(JSON.parse(raw) as WebCartState);
    } catch {
      setCart(null);
    }
  }, [slug]);

  const persist = useCallback(
    (next: WebCartState | null) => {
      setCart(next);
      if (!slug) return;
      try {
        if (!next || next.items.length === 0) {
          localStorage.removeItem(storageKey(slug));
          return;
        }
        localStorage.setItem(storageKey(slug), JSON.stringify(next));
      } catch {
        /* ignore quota / private browsing */
      }
    },
    [slug],
  );

  const itemCount = useMemo(
    () => cart?.items.reduce((sum, item) => sum + item.quantity, 0) ?? 0,
    [cart],
  );

  const subtotal = useMemo(
    () => cart?.items.reduce((sum, item) => sum + item.total_price, 0) ?? 0,
    [cart],
  );

  const addItem = useCallback(
    (base: Omit<WebCartState, 'items'>, line: WebCartLine) => {
      if (cart && cart.restaurantId !== base.restaurantId) {
        throw new Error('different_restaurant');
      }
      const existing = cart?.items ?? [];
      const idx = existing.findIndex((i) => i.id === line.id);
      let items: WebCartLine[];
      if (idx >= 0) {
        items = [...existing];
        const prev = items[idx];
        items[idx] = {
          ...prev,
          quantity: prev.quantity + line.quantity,
          total_price: roundMoney(prev.unit_price * (prev.quantity + line.quantity)),
        };
      } else {
        items = [...existing, line];
      }
      persist({ ...base, items });
    },
    [cart, persist],
  );

  const clearCart = useCallback(() => persist(null), [persist]);

  const updateLineQuantity = useCallback(
    (lineId: string, quantity: number) => {
      if (!cart) return;
      if (quantity <= 0) {
        const items = cart.items.filter((i) => i.id !== lineId);
        persist(items.length ? { ...cart, items } : null);
        return;
      }
      const items = cart.items.map((line) => {
        if (line.id !== lineId) return line;
        return {
          ...line,
          quantity,
          total_price: roundMoney(line.unit_price * quantity),
        };
      });
      persist({ ...cart, items });
    },
    [cart, persist],
  );

  const removeLine = useCallback(
    (lineId: string) => {
      if (!cart) return;
      const items = cart.items.filter((i) => i.id !== lineId);
      persist(items.length ? { ...cart, items } : null);
    },
    [cart, persist],
  );

  return { cart, itemCount, subtotal, addItem, clearCart, persist, updateLineQuantity, removeLine };
}

function roundMoney(value: number) {
  return Math.round(value * 100) / 100;
}
