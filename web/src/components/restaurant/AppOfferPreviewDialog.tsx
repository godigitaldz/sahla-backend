'use client';

import { ar } from '@/lib/i18n/ar';
import { SAHLA_APP_LINKS } from '@/lib/appLinks';
import type { AppOfferPreview } from '@/lib/appOffers/toAppOfferPreview';

type Props = {
  offer: AppOfferPreview | null;
  open: boolean;
  onClose: () => void;
};

export function AppOfferPreviewDialog({ offer, open, onClose }: Props) {
  if (!open || !offer) return null;

  return (
    <div
      className="fixed inset-0 z-[80] flex items-end justify-center bg-black/45 p-4 sm:items-center"
      role="dialog"
      aria-modal="true"
      aria-labelledby="app-offer-preview-title"
      onClick={onClose}
    >
      <div
        className="w-full max-w-sm rounded-2xl bg-white p-5 shadow-xl"
        onClick={(e) => e.stopPropagation()}
      >
        <h2 id="app-offer-preview-title" className="text-lg font-bold text-gray-900">
          {ar.appOfferPreviewTitle}
        </h2>
        <p className="mt-2 text-sm font-semibold text-gray-800">{offer.title}</p>
        <p className="mt-3 text-sm leading-relaxed text-gray-600">{ar.appOfferPreviewBody}</p>

        <div className="mt-5 flex flex-col gap-2">
          <a
            href={SAHLA_APP_LINKS.appStore}
            target="_blank"
            rel="noopener noreferrer"
            className="flex h-11 items-center justify-center rounded-xl bg-black text-sm font-semibold text-white"
          >
            {ar.downloadAppStore}
          </a>
          <a
            href={SAHLA_APP_LINKS.playStore}
            target="_blank"
            rel="noopener noreferrer"
            className="flex h-11 items-center justify-center rounded-xl border border-gray-300 text-sm font-semibold text-gray-900"
          >
            {ar.downloadPlayStore}
          </a>
          <button
            type="button"
            onClick={onClose}
            className="mt-1 text-sm font-medium text-gray-500"
          >
            {ar.close}
          </button>
        </div>
      </div>
    </div>
  );
}
