'use client';

import { SAHLA_COLORS } from '@/lib/theme';
import { ar } from '@/lib/i18n/ar';

type Props = {
  count: number;
  onOpenCheckout: () => void;
};

export function FloatingCart({ count, onOpenCheckout }: Props) {
  if (count <= 0) return null;

  return (
    <button
      type="button"
      onClick={onOpenCheckout}
      aria-label={ar.openCart}
      className="fixed bottom-6 start-4 z-30 flex h-[65px] w-[65px] items-center justify-center rounded-full bg-white shadow-lg"
      style={{ boxShadow: '0 4px 8px rgba(0,0,0,0.15)' }}
    >
      <span className="text-3xl text-black">🛒</span>
      <span
        className="absolute -end-0.5 -top-0.5 flex h-5 min-w-5 items-center justify-center rounded-full border-2 border-white px-1 text-xs font-bold text-white"
        style={{ backgroundColor: SAHLA_COLORS.cartBadge }}
      >
        {count}
      </span>
    </button>
  );
}
