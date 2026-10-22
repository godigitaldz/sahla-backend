'use client';

import { useEffect, useMemo, useState } from 'react';
import { ar, formatDa } from '@/lib/i18n/ar';
import {
  computeRegularUnitPrice,
  defaultPricingForVariant,
  everyVariantHasSinglePricingOption,
  getAvailableVariants,
  getVariantPricingForDisplay,
  getVariantSupplements,
  itemDisplayDescription,
  itemDisplayName,
  pricingDescriptionLine,
  pricingSizeLabel,
  resolvePrimaryVariantId,
  supplementDisplayName,
  variantDescriptionLine,
  variantDisplayLabel,
  type RawPricing,
  type WebMenuItem,
} from '@/lib/menuCatalog';
import { SAHLA_COLORS } from '@/lib/theme';

function asArray<T>(value: unknown): T[] {
  return Array.isArray(value) ? (value as T[]) : [];
}

type Props = {
  item: WebMenuItem;
  open: boolean;
  onClose: () => void;
  /** When set (variant list card), skip variant chips and open directly on this variant. */
  lockedVariantId?: string | null;
  onAdd: (payload: {
    quantity: number;
    unitPrice: number;
    pricingSize?: string | null;
    variantId?: string | null;
    variantName?: string | null;
    supplementNames: string[];
    specialInstructions?: string;
  }) => void;
};

export type SheetMenuItem = WebMenuItem;

function OptionRow({
  selected,
  label,
  description,
  price,
  onSelect,
}: {
  selected: boolean;
  label: string;
  description?: string | null;
  price: number;
  onSelect: () => void;
}) {
  return (
    <button
      type="button"
      onClick={onSelect}
      className={`flex w-full items-center gap-3 rounded-xl border px-3 py-3 text-start transition active:scale-[0.99] ${
        selected
          ? 'border-orange-500 bg-orange-50 shadow-sm'
          : 'border-gray-200 bg-gray-50 hover:border-gray-300'
      }`}
    >
      <span
        className={`flex h-5 w-5 shrink-0 items-center justify-center rounded-full border-2 text-[10px] font-bold ${
          selected ? 'border-orange-500 bg-orange-500 text-white' : 'border-gray-300 bg-white text-transparent'
        }`}
        aria-hidden
      >
        ✓
      </span>
      <div className="min-w-0 flex-1">
        <p className="text-sm font-medium leading-snug text-gray-900">{label}</p>
        {description ? <p className="mt-0.5 text-xs leading-relaxed text-gray-500">{description}</p> : null}
      </div>
      <span className="shrink-0 text-sm font-semibold text-[#fc9d2d]">{formatDa(price)}</span>
    </button>
  );
}

export function MenuItemSheet({ item, open, onClose, onAdd, lockedVariantId = null }: Props) {
  const title = itemDisplayName(item);
  const description = itemDisplayDescription(item);
  const variants = getAvailableVariants(item);
  const variantLocked = Boolean(lockedVariantId?.trim());
  const useVerticalPicker =
    !variantLocked &&
    variants.length > 1 &&
    everyVariantHasSinglePricingOption(item, variants);

  const [quantity, setQuantity] = useState(1);
  const [selectedVariantId, setSelectedVariantId] = useState<string | null>(null);
  const [selectedPricing, setSelectedPricing] = useState<RawPricing | null>(null);
  const [selectedSupplements, setSelectedSupplements] = useState<string[]>([]);
  const [note, setNote] = useState('');
  const [toast, setToast] = useState<string | null>(null);
  const [formError, setFormError] = useState<string | null>(null);

  useEffect(() => {
    if (!open) return;
    setQuantity(1);
    setSelectedSupplements([]);
    setNote('');
    setToast(null);
    setFormError(null);

    const primaryId = resolvePrimaryVariantId(item, lockedVariantId);
    if (primaryId) {
      setSelectedVariantId(primaryId);
      setSelectedPricing(defaultPricingForVariant(item, primaryId));
      return;
    }

    setSelectedVariantId(null);
    setSelectedPricing(null);
  }, [open, item.id, lockedVariantId, item]);

  const activeVariantId = resolvePrimaryVariantId(item, lockedVariantId ?? selectedVariantId);
  const activeVariant = variants.find((v) => String(v.id ?? '') === activeVariantId) ?? null;
  const variantPricing = activeVariantId ? getVariantPricingForDisplay(item, activeVariantId) : [];
  const supplements = activeVariantId ? getVariantSupplements(item, activeVariantId) : [];

  const unitPrice = useMemo(
    () => computeRegularUnitPrice(item, selectedPricing, selectedSupplements),
    [item, selectedPricing, selectedSupplements],
  );

  const showVariantPicker = variants.length > 1 && !variantLocked;
  const showSizePicker = !useVerticalPicker && variantPricing.length > 0;
  const hasOptions = showVariantPicker || showSizePicker || supplements.length > 0;

  const selectVariant = (variantId: string) => {
    const isSelected = selectedVariantId === variantId;
    if (isSelected) {
      setSelectedVariantId(null);
      setSelectedPricing(null);
      return;
    }
    setSelectedVariantId(variantId);
    setSelectedPricing(defaultPricingForVariant(item, variantId));
    setSelectedSupplements([]);
  };

  const selectPricing = (pricing: RawPricing) => {
    const same = selectedPricing?.id === pricing.id;
    if (same) {
      setSelectedPricing(null);
      return;
    }
    setSelectedPricing(pricing);
    if (pricing.variant_id && !selectedVariantId) {
      setSelectedVariantId(String(pricing.variant_id));
    }
  };

  const toggleSupplement = (key: string) => {
    setSelectedSupplements((prev) =>
      prev.includes(key) ? prev.filter((x) => x !== key) : [...prev, key],
    );
  };

  if (!open) return null;

  const handleAdd = () => {
    const pricingRows = asArray(item.pricing_options);
    if (!variantLocked && variants.length > 1 && !selectedVariantId) {
      setFormError(`يرجى اختيار ${ar.chooseVariant.toLowerCase()}`);
      return;
    }
    if (
      !useVerticalPicker &&
      variantPricing.length > 0 &&
      !selectedPricing &&
      pricingRows.length > 0
    ) {
      setFormError(`يرجى اختيار ${ar.size.toLowerCase()}`);
      return;
    }
    setFormError(null);
    onAdd({
      quantity,
      unitPrice,
      pricingSize: selectedPricing?.size ?? null,
      variantId: activeVariantId,
      variantName: activeVariant ? variantDisplayLabel(item, activeVariant) : null,
      supplementNames: selectedSupplements,
      specialInstructions: note.trim() || undefined,
    });
    setToast(`${title} ${ar.addedToCart}`);
    setTimeout(() => {
      setToast(null);
      onClose();
    }, 900);
  };

  return (
    <div
      className="fixed inset-0 z-[100] flex flex-col justify-end"
      role="dialog"
      aria-modal="true"
      aria-label={title}
    >
      <button
        type="button"
        className="absolute inset-0 bg-black/45"
        aria-label={ar.close}
        onClick={onClose}
      />

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
            <h2 className="truncate text-lg font-bold text-gray-900">{title}</h2>
            <p className="text-xs text-gray-500">{ar.customizeOrder}</p>
          </div>
        </div>

        <div className="min-h-0 flex-1 overflow-y-auto overscroll-contain px-4 py-4">
          {description ? (
            <p className="mb-4 text-sm leading-relaxed text-gray-600">{description}</p>
          ) : null}

          {hasOptions ? (
            <div className="space-y-5 rounded-2xl border border-gray-200 bg-white p-4 shadow-sm">
              {showVariantPicker ? (
                useVerticalPicker ? (
                  <section>
                    <div className="mb-3 flex items-center justify-between gap-2">
                      <span className="text-sm font-semibold text-gray-900">{ar.chooseVariant}</span>
                      <span className="text-xs text-gray-500">{ar.required}</span>
                    </div>
                    <div className="space-y-2">
                      {variants.map((variant) => {
                        const id = String(variant.id ?? '');
                        const pricing = getVariantPricingForDisplay(item, id)[0];
                        const selected = selectedVariantId === id;
                        const desc =
                          (pricing && pricingDescriptionLine(pricing)) ||
                          variantDescriptionLine(variant);
                        return (
                          <OptionRow
                            key={id}
                            selected={selected}
                            label={variantDisplayLabel(item, variant)}
                            description={desc}
                            price={Number(pricing?.price ?? item.price)}
                            onSelect={() => selectVariant(id)}
                          />
                        );
                      })}
                    </div>
                  </section>
                ) : (
                  <section>
                    <p className="mb-3 text-sm font-semibold text-gray-900">{ar.chooseVariant}</p>
                    <div className="flex flex-wrap gap-2">
                      {variants.map((variant) => {
                        const id = String(variant.id ?? '');
                        const selected = selectedVariantId === id;
                        return (
                          <button
                            key={id}
                            type="button"
                            onClick={() => selectVariant(id)}
                            className="rounded-full border px-4 py-2 text-sm transition active:scale-[0.98]"
                            style={{
                              backgroundColor: selected ? '#d47b00' : '#f5f5f5',
                              borderColor: selected ? '#d47b00' : '#d1d5db',
                              color: selected ? '#fff' : '#111',
                              fontWeight: selected ? 600 : 400,
                            }}
                          >
                            {variantDisplayLabel(item, variant)}
                          </button>
                        );
                      })}
                    </div>
                  </section>
                )
              ) : null}

              {showSizePicker ? (
                <section>
                  <div className="mb-3 flex items-center justify-between gap-2">
                    <span className="text-sm font-semibold text-gray-900">
                      {variants.length === 1 &&
                      variantPricing.length === 1 &&
                      !pricingSizeLabel(variantPricing[0])
                        ? ar.chooseVariant
                        : ar.size}
                    </span>
                    <span className="text-xs text-gray-500">{ar.required}</span>
                  </div>
                  <div className="space-y-2">
                    {variantPricing.map((pricing) => {
                      const selected = selectedPricing?.id === pricing.id;
                      const sizeLabel =
                        pricingSizeLabel(pricing) ||
                        (activeVariant ? variantDisplayLabel(item, activeVariant) : title);
                      const desc =
                        pricingDescriptionLine(pricing) ||
                        (activeVariant ? variantDescriptionLine(activeVariant) : null);
                      return (
                        <OptionRow
                          key={String(pricing.id ?? pricing.size ?? pricing.display_order)}
                          selected={selected}
                          label={sizeLabel}
                          description={desc}
                          price={Number(pricing.price ?? 0)}
                          onSelect={() => selectPricing(pricing)}
                        />
                      );
                    })}
                  </div>
                </section>
              ) : null}

              {supplements.length > 0 ? (
                <section>
                  <p className="mb-3 text-sm font-semibold text-gray-900">{ar.extras}</p>
                  <div className="space-y-2">
                    {supplements.map((s) => {
                      const key = String(s.name ?? s.id ?? '');
                      const checked = selectedSupplements.includes(key);
                      return (
                        <button
                          key={key}
                          type="button"
                          onClick={() => toggleSupplement(key)}
                          className={`flex w-full items-center gap-3 rounded-xl border px-3 py-2.5 text-start transition active:scale-[0.99] ${
                            checked
                              ? 'border-orange-400 bg-orange-50'
                              : 'border-gray-200 bg-gray-50 hover:border-gray-300'
                          }`}
                        >
                          <span
                            className={`flex h-5 w-5 shrink-0 items-center justify-center rounded border-2 ${
                              checked ? 'border-orange-500 bg-orange-500 text-white' : 'border-gray-300 bg-white'
                            }`}
                          >
                            {checked ? <span className="text-[10px] font-bold">✓</span> : null}
                          </span>
                          <span className="min-w-0 flex-1 text-sm text-gray-900">
                            {supplementDisplayName(s)}
                          </span>
                          <span className="shrink-0 text-sm font-medium text-gray-700">
                            {formatDa(Number(s.price ?? 0))}
                          </span>
                        </button>
                      );
                    })}
                  </div>
                </section>
              ) : null}
            </div>
          ) : null}

          <div className="mt-4">
            <p className="mb-2 text-sm font-semibold text-gray-900">{ar.specialNote}</p>
            <textarea
              value={note}
              onChange={(e) => setNote(e.target.value)}
              className="w-full rounded-xl border border-gray-200 p-3 text-sm outline-none focus:border-orange-400 focus:ring-2 focus:ring-orange-100"
              rows={2}
              placeholder={ar.optional}
              dir="rtl"
            />
          </div>
        </div>

        <div className="shrink-0 border-t bg-white px-4 py-3 pb-[max(0.75rem,env(safe-area-inset-bottom))] shadow-[0_-4px_16px_rgba(0,0,0,0.06)]">
          {formError ? (
            <div className="mb-2 rounded-lg bg-red-50 px-3 py-2 text-center text-sm text-red-700">
              {formError}
            </div>
          ) : null}
          {toast ? (
            <div className="mb-2 rounded-lg bg-green-600 px-3 py-2 text-center text-sm text-white">
              {toast}
            </div>
          ) : null}
          <div className="flex items-center gap-3">
            <div className="flex items-center rounded-full border border-gray-300 bg-white">
              <button
                type="button"
                className="px-3 py-2.5 text-lg leading-none active:bg-gray-100"
                onClick={() => setQuantity((q) => Math.max(1, q - 1))}
                aria-label="−"
              >
                −
              </button>
              <span className="min-w-8 text-center text-sm font-semibold">{quantity}</span>
              <button
                type="button"
                className="px-3 py-2.5 text-lg leading-none active:bg-gray-100"
                onClick={() => setQuantity((q) => q + 1)}
                aria-label="+"
              >
                +
              </button>
            </div>
            <button
              type="button"
              onClick={handleAdd}
              className="flex-1 rounded-full py-3.5 text-center text-sm font-semibold text-white active:opacity-90"
              style={{ backgroundColor: SAHLA_COLORS.primary }}
            >
              {ar.addToCart} · {formatDa(unitPrice * quantity)}
            </button>
          </div>
        </div>
      </div>
    </div>
  );
}
