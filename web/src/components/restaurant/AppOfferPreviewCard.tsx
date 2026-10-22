'use client';

import { ar } from '@/lib/i18n/ar';
import type { AppOfferPreview } from '@/lib/appOffers/toAppOfferPreview';
import { SAHLA_COLORS } from '@/lib/theme';
import { RemoteImage } from '@/components/ui/RemoteImage';

type Props = {
  offer: AppOfferPreview;
  onTap: () => void;
};

function imageTopBadge(offer: AppOfferPreview): string | null {
  if (offer.discountPercent != null && offer.discountPercent > 0) {
    return `${offer.discountPercent}% خصم`;
  }
  const promo = offer.promoBadge?.trim();
  return promo || null;
}

/** Shared LTO + special-pack carousel tile (matches home LTO card stack). */
export function AppOfferPreviewCard({ offer, onTap }: Props) {
  const topBadge = imageTopBadge(offer);

  return (
    <button
      type="button"
      onClick={onTap}
      className="block w-[132px] shrink-0 snap-start border-0 bg-transparent p-0 text-start"
    >
      <article className="flex w-[132px] flex-col">
        <div className="relative aspect-square w-full overflow-hidden rounded-xl bg-[#F4F4F4] shadow-[0_2px_10px_rgba(0,0,0,0.08)]">
          <RemoteImage src={offer.imageUrl} alt={offer.title} fill className="object-cover" />

          {topBadge ? (
            <span
              className="absolute end-1.5 top-1.5 z-[1] max-w-[90%] rounded-md px-1.5 py-0.5 text-[9px] font-bold leading-tight text-black shadow-sm"
              style={{ backgroundColor: SAHLA_COLORS.ltoYellow }}
            >
              {topBadge}
            </span>
          ) : null}

          {offer.timeRemaining ? (
            <span className="absolute bottom-1.5 start-1.5 z-[1] inline-flex items-center gap-0.5 rounded-full bg-white/95 px-1.5 py-0.5 text-[8px] font-semibold text-gray-700 shadow">
              <span aria-hidden>⏱</span>
              {offer.timeRemaining}
            </span>
          ) : null}
        </div>

        <div className="mt-1.5 flex w-full flex-col items-start gap-1">
          <div
            className="inline-flex max-w-full rounded-md px-2 py-0.5"
            style={{ backgroundColor: SAHLA_COLORS.ltoYellow }}
          >
            <span className="text-[12px] font-bold leading-none text-black">
              {Math.round(offer.price)} {ar.currency}
            </span>
            {offer.originalPrice != null && offer.originalPrice > offer.price ? (
              <span className="ms-1.5 text-[9px] font-medium text-gray-700 line-through">
                {Math.round(offer.originalPrice)}
              </span>
            ) : null}
          </div>

          <p className="line-clamp-2 w-full text-start text-[10px] font-semibold leading-snug text-gray-900">
            {offer.title}
          </p>

          {offer.subtitleLabel ? (
            <p className="w-full truncate text-start text-[9px] font-medium leading-tight text-gray-500">
              {offer.subtitleLabel}
            </p>
          ) : null}
        </div>
      </article>
    </button>
  );
}
