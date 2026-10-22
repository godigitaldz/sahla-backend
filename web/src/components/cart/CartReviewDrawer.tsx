'use client';

import { ar, formatDa } from '@/lib/i18n/ar';
import { SAHLA_COLORS } from '@/lib/theme';
import type { WebCartLine } from '@/lib/cart/useWebCart';
import { RemoteImage } from '@/components/ui/RemoteImage';

type Props = {
  open: boolean;
  restaurantName: string;
  items: WebCartLine[];
  subtotal: number;
  onClose: () => void;
  onProceed: () => void;
  onUpdateQuantity: (lineId: string, quantity: number) => void;
  onRemoveLine: (lineId: string) => void;
};

function lineDetail(line: WebCartLine): string | null {
  const parts: string[] = [];
  if (line.variant_name?.trim()) parts.push(line.variant_name.trim());
  if (line.pricing_size?.trim()) parts.push(line.pricing_size.trim());
  if (line.supplement_names?.length) parts.push(line.supplement_names.join('، '));
  if (line.special_instructions?.trim()) parts.push(line.special_instructions.trim());
  return parts.length ? parts.join(' · ') : null;
}

function CartLineRow({
  line,
  onUpdateQuantity,
  onRemoveLine,
}: {
  line: WebCartLine;
  onUpdateQuantity: (lineId: string, quantity: number) => void;
  onRemoveLine: (lineId: string) => void;
}) {
  const detail = lineDetail(line);

  return (
    <div className="flex gap-3 border-b border-gray-100 py-3 last:border-0">
      <div className="relative h-16 w-16 shrink-0 overflow-hidden rounded-xl bg-gray-100">
        <RemoteImage
          src={line.image}
          alt={line.name}
          width={64}
          height={64}
          className="h-full w-full object-cover"
          fallbackClassName="h-full w-full rounded-xl"
        />
      </div>

      <div className="min-w-0 flex-1">
        <p className="text-sm font-semibold leading-snug text-gray-900">{line.name}</p>
        {detail ? <p className="mt-0.5 text-[11px] leading-relaxed text-gray-500">{detail}</p> : null}
        <p className="mt-1 text-sm font-bold text-gray-900">{formatDa(line.total_price)}</p>

        <div className="mt-2 flex items-center justify-between gap-2">
          <div className="flex items-center rounded-full border border-gray-300 bg-white">
            <button
              type="button"
              className="px-2.5 py-1 text-base leading-none active:bg-gray-100"
              onClick={() => onUpdateQuantity(line.id, line.quantity - 1)}
              aria-label="−"
            >
              −
            </button>
            <span className="min-w-7 text-center text-sm font-semibold">{line.quantity}</span>
            <button
              type="button"
              className="px-2.5 py-1 text-base leading-none active:bg-gray-100"
              onClick={() => onUpdateQuantity(line.id, line.quantity + 1)}
              aria-label="+"
            >
              +
            </button>
          </div>
          <button
            type="button"
            onClick={() => onRemoveLine(line.id)}
            className="text-xs font-semibold text-red-600 underline-offset-2 hover:underline"
          >
            {ar.removeItem}
          </button>
        </div>
      </div>
    </div>
  );
}

export function CartReviewDrawer({
  open,
  restaurantName,
  items,
  subtotal,
  onClose,
  onProceed,
  onUpdateQuantity,
  onRemoveLine,
}: Props) {
  if (!open) return null;

  return (
    <div
      className="fixed inset-0 z-[100] flex flex-col justify-end"
      role="dialog"
      aria-modal="true"
      aria-label={ar.cartTitle}
    >
      <button type="button" className="absolute inset-0 bg-black/45" aria-label={ar.close} onClick={onClose} />

      <div className="relative flex max-h-[min(92dvh,100%)] flex-col overflow-hidden rounded-t-3xl bg-white shadow-2xl">
        <div className="flex shrink-0 justify-center pt-2">
          <span className="h-1 w-10 rounded-full bg-gray-300" aria-hidden />
        </div>

        <div className="flex shrink-0 items-center gap-3 border-b px-4 pb-3 pt-1">
          <button
            type="button"
            className="flex h-10 w-10 shrink-0 items-center justify-center rounded-full bg-gray-100 active:bg-gray-200"
            onClick={onClose}
            aria-label={ar.close}
          >
            ✕
          </button>
          <div className="min-w-0 flex-1 text-start">
            <h2 className="text-xl font-bold text-gray-900">{ar.cartTitle}</h2>
            <p className="text-sm text-gray-500">{restaurantName}</p>
          </div>
        </div>

        <div className="min-h-0 flex-1 overflow-y-auto overscroll-contain px-4 py-2">
          <p className="mb-2 text-xs text-gray-500">{ar.reviewCart}</p>

          {items.length === 0 ? (
            <p className="py-8 text-center text-sm text-gray-500">{ar.emptyCart}</p>
          ) : (
            <div className="rounded-2xl border border-gray-100 bg-white px-3 shadow-sm">
              {items.map((line) => (
                <CartLineRow
                  key={line.id}
                  line={line}
                  onUpdateQuantity={onUpdateQuantity}
                  onRemoveLine={onRemoveLine}
                />
              ))}
            </div>
          )}

          {items.length > 0 ? (
            <div className="mt-4 rounded-xl bg-gray-50 p-3 text-sm">
              <div className="flex justify-between gap-3 font-bold">
                <span>{ar.subtotal}</span>
                <span>{formatDa(subtotal)}</span>
              </div>
            </div>
          ) : null}
        </div>

        <div className="shrink-0 border-t bg-white px-4 py-3 pb-[max(0.75rem,env(safe-area-inset-bottom))] shadow-[0_-4px_16px_rgba(0,0,0,0.06)]">
          <button
            type="button"
            disabled={items.length === 0}
            onClick={onProceed}
            className="w-full rounded-full py-3.5 font-semibold text-white disabled:opacity-50 active:opacity-90"
            style={{ backgroundColor: SAHLA_COLORS.primary }}
          >
            {ar.proceedToCheckout}
          </button>
        </div>
      </div>
    </div>
  );
}
