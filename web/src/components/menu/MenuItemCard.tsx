'use client';

import { ar, formatDa } from '@/lib/i18n/ar';
import {
  displayItemImage,
  itemDisplayName,
  type WebDisplayMenuItem,
} from '@/lib/menuCatalog';
import { RemoteImage } from '@/components/ui/RemoteImage';

type Props = {
  item: WebDisplayMenuItem;
  onTap: () => void;
};

function RatingStars({ rating }: { rating: number }) {
  return (
    <span className="inline-flex items-center gap-0.5" aria-hidden>
      {Array.from({ length: 5 }, (_, index) => {
        const star = index + 1;
        const filled = rating >= star;
        const half = !filled && rating >= star - 0.5;
        return (
          <span key={star} className="text-[13px] leading-none text-amber-400">
            {filled ? '★' : half ? '⯨' : '☆'}
          </span>
        );
      })}
    </span>
  );
}

export function MenuItemCard({ item, onTap }: Props) {
  const unavailable = item.is_available === false;
  const rating = item.rating ?? 0;
  const reviewCount = item.review_count ?? 0;
  const prepTime = item.preparation_time ?? 15;
  const title = itemDisplayName(item);
  const imageUrl = displayItemImage(item);

  return (
    <button
      type="button"
      onClick={onTap}
      disabled={unavailable}
      className="block w-full border-0 bg-transparent p-0 text-start disabled:opacity-60"
    >
      <div className="flex items-stretch gap-3 py-3">
        <div className="flex min-w-0 flex-1 flex-col justify-center text-start">
          {unavailable ? (
            <p className="mb-1 text-[11px] font-semibold text-gray-600">{ar.unavailable}</p>
          ) : null}

          <h3 className="text-[15px] font-semibold leading-[1.35] text-gray-900">{title}</h3>

          <div className="mt-2 flex items-center gap-1 text-[11px] leading-none text-gray-500">
            <RatingStars rating={rating} />
            <span>({reviewCount})</span>
          </div>

          <div className="mt-2.5 inline-flex w-fit items-center gap-2 rounded-lg border border-gray-300 bg-white px-3 py-1.5 shadow-sm">
            <span className="text-sm font-bold leading-none text-gray-900">{formatDa(item.price)}</span>
            <span className="h-3.5 w-px shrink-0 bg-gray-300" aria-hidden />
            <span className="inline-flex items-center gap-1 text-[11px] leading-none text-gray-600">
              <svg
                viewBox="0 0 24 24"
                className="h-3.5 w-3.5 shrink-0 text-gray-500"
                fill="none"
                stroke="currentColor"
                strokeWidth="2"
                aria-hidden
              >
                <circle cx="12" cy="12" r="9" />
                <path d="M12 7v5l3 2" />
              </svg>
              {prepTime} {ar.min}
            </span>
          </div>
        </div>

        <div className="relative shrink-0 self-center">
          <RemoteImage
            src={imageUrl}
            alt={title}
            width={110}
            height={110}
            className="h-[110px] w-[110px] rounded-xl object-cover shadow-[0_4px_14px_rgba(0,0,0,0.12)]"
            fallbackClassName="h-[110px] w-[110px] rounded-xl"
          />
          {!unavailable ? (
            <span
              className="absolute bottom-2 end-2 flex h-9 w-9 items-center justify-center rounded-full bg-white text-2xl font-light leading-none shadow-md"
              style={{ color: '#E91E63' }}
              aria-hidden
            >
              +
            </span>
          ) : null}
        </div>
      </div>
      <div className="h-px bg-gray-200" />
    </button>
  );
}

export type { WebDisplayMenuItem as PublicMenuItem };
