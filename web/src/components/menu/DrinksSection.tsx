'use client';

import { useState } from 'react';
import { ar, formatDa } from '@/lib/i18n/ar';
import { drinkSizeLabel, itemDisplayName, pickItemImage, type WebMenuItem } from '@/lib/menuCatalog';
import { RemoteImage } from '@/components/ui/RemoteImage';
import { SAHLA_COLORS } from '@/lib/theme';

type Props = {
  drinks: WebMenuItem[];
  onAdd: (item: WebMenuItem, quantity: number) => void;
};

function QuantityButton({
  label,
  disabled,
  onClick,
  accent,
}: {
  label: string;
  disabled?: boolean;
  onClick: () => void;
  accent?: boolean;
}) {
  return (
    <button
      type="button"
      disabled={disabled}
      onClick={onClick}
      aria-label={label}
      className={`flex h-7 w-7 shrink-0 items-center justify-center rounded-full text-base font-medium leading-none transition disabled:text-gray-300 ${
        accent ? 'text-orange-500' : 'text-gray-500'
      }`}
    >
      {label}
    </button>
  );
}

export function DrinksSection({ drinks, onAdd }: Props) {
  const [quantities, setQuantities] = useState<Record<string, number>>({});
  const [toast, setToast] = useState<string | null>(null);

  if (!drinks.length) return null;

  const setQty = (id: string, value: number) => {
    setQuantities((prev) => ({ ...prev, [id]: Math.max(0, Math.min(10, value)) }));
  };

  const handleAdd = (drink: WebMenuItem) => {
    const qty = quantities[drink.id] ?? 0;
    if (qty <= 0) return;
    onAdd(drink, qty);
    setQty(drink.id, 0);
    setToast(ar.addedToCart);
    window.setTimeout(() => setToast(null), 1200);
  };

  return (
    <section className="mb-8">
      <h2 className="mb-2 text-start text-base font-semibold text-gray-900">{ar.drinks}</h2>

      {toast ? (
        <div className="mb-3 rounded-xl bg-green-600 px-3 py-2 text-center text-sm font-medium text-white shadow-sm">
          {toast}
        </div>
      ) : null}

      <div className="overflow-x-auto pb-1 [scrollbar-width:none] [&::-webkit-scrollbar]:hidden">
        <div className="flex w-max min-w-full gap-3 pe-1">
          {drinks.map((drink) => {
            const qty = quantities[drink.id] ?? 0;
            const size = drinkSizeLabel(drink);
            const title = itemDisplayName(drink);
            const canAdd = qty > 0;

            return (
              <article
                key={drink.id}
                className="flex w-[118px] shrink-0 flex-col rounded-xl border border-gray-100 bg-white shadow-[0_2px_12px_rgba(0,0,0,0.07)]"
              >
                <div className="flex items-center justify-between gap-1 px-2 pt-2" dir="ltr">
                  <span
                    className="rounded-md px-2 py-0.5 text-[9px] font-bold leading-none text-white"
                    style={{ backgroundColor: SAHLA_COLORS.primary }}
                  >
                    + {formatDa(drink.price)}
                  </span>
                  {size ? (
                    <span className="rounded-md bg-gray-100 px-2 py-0.5 text-[9px] font-semibold leading-none text-gray-700">
                      {size}
                    </span>
                  ) : (
                    <span className="w-8" aria-hidden />
                  )}
                </div>

                <div className="mx-2 mt-1.5 flex h-[84px] items-center justify-center rounded-lg bg-gray-50 px-2 py-1">
                  <RemoteImage
                    src={pickItemImage(drink)}
                    alt={title}
                    width={72}
                    height={72}
                    className="max-h-[72px] w-auto max-w-full object-contain"
                    fallbackClassName="h-[72px] w-[72px] rounded-lg"
                  />
                </div>

                <p className="mx-2 mt-1.5 line-clamp-2 text-center text-[11px] font-semibold leading-[1.25] text-gray-900">
                  {title}
                </p>

                <div className="mx-2 mt-1.5 flex items-center justify-between rounded-full border border-gray-200 bg-gray-50 px-0.5">
                  <QuantityButton
                    label="−"
                    disabled={qty <= 0}
                    onClick={() => setQty(drink.id, qty - 1)}
                  />
                  <span className="min-w-[1.25rem] text-center text-xs font-bold tabular-nums text-gray-800">
                    {qty}
                  </span>
                  <QuantityButton
                    label="+"
                    accent
                    disabled={qty >= 10}
                    onClick={() => setQty(drink.id, qty + 1)}
                  />
                </div>

                <button
                  type="button"
                  disabled={!canAdd}
                  onClick={() => handleAdd(drink)}
                  className={`mx-2 mb-2 mt-1.5 flex h-8 items-center justify-center rounded-full text-[11px] font-bold transition active:scale-[0.98] ${
                    canAdd
                      ? 'text-white shadow-sm'
                      : 'border border-gray-200 bg-gray-50 text-gray-400'
                  }`}
                  style={canAdd ? { backgroundColor: SAHLA_COLORS.primary } : undefined}
                >
                  {ar.add}
                </button>
              </article>
            );
          })}
        </div>
      </div>
    </section>
  );
}
