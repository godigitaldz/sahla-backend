'use client';

import { useEffect, useMemo, useState } from 'react';
import { ar } from '@/lib/i18n/ar';
import { buildAppOfferPreviews } from '@/lib/appOffers/toAppOfferPreview';
import type { PublicDeliveryPromo } from '@/lib/appOffers/promoTypes';
import type { WebMenuItem } from '@/lib/menuCatalog';
import type { DeliveryFeeQuoteState } from '@/lib/location/useDeliveryFeeQuote';
import type { CustomerLocation } from '@/lib/location/customerLocation';
import { AppOfferWaveSection } from '@/components/restaurant/AppOfferWaveSection';
import { AppOfferPreviewCard } from '@/components/restaurant/AppOfferPreviewCard';
import { AppOfferPreviewDialog } from '@/components/restaurant/AppOfferPreviewDialog';
import type { AppOfferPreview } from '@/lib/appOffers/toAppOfferPreview';

type Props = {
  slug: string;
  restaurantId: string;
  location: CustomerLocation | null;
  feeQuote: DeliveryFeeQuoteState;
  locationLoading: boolean;
  onRequestLocation: () => void;
  inline?: boolean;
};

export function AppExclusiveOffersSection({
  slug,
  restaurantId,
  location,
  feeQuote,
  locationLoading,
  onRequestLocation,
  inline = false,
}: Props) {
  const [catalogItems, setCatalogItems] = useState<WebMenuItem[]>([]);
  const [offersLoaded, setOffersLoaded] = useState(false);
  const [promos, setPromos] = useState<PublicDeliveryPromo[]>([]);
  const [feesByRestaurantId, setFeesByRestaurantId] = useState<Record<string, number>>({});
  const [selected, setSelected] = useState<AppOfferPreview | null>(null);

  useEffect(() => {
    let cancelled = false;
    setOffersLoaded(false);

    fetch(`/api/public/restaurants/${encodeURIComponent(slug)}/app-offers`)
      .then(async (res) => {
        const payload = await res.json();
        if (cancelled) return;
        if (payload?.success && Array.isArray(payload.data?.items)) {
          setCatalogItems(payload.data.items as WebMenuItem[]);
        } else {
          setCatalogItems([]);
        }
      })
      .catch((error) => {
        console.warn('[AppExclusiveOffersSection] offers fetch failed:', error);
        if (!cancelled) setCatalogItems([]);
      })
      .finally(() => {
        if (!cancelled) setOffersLoaded(true);
      });

    return () => {
      cancelled = true;
    };
  }, [slug]);

  useEffect(() => {
    let cancelled = false;

    fetch(`/api/public/restaurants/${encodeURIComponent(slug)}/app-promos`)
      .then(async (res) => {
        const payload = await res.json();
        if (cancelled) return;
        if (payload?.success && Array.isArray(payload.data)) {
          setPromos(payload.data as PublicDeliveryPromo[]);
        }
      })
      .catch((error) => {
        console.warn('[AppExclusiveOffersSection] promos fetch failed:', error);
      });

    return () => {
      cancelled = true;
    };
  }, [slug]);

  const restaurantIds = useMemo(() => {
    const ids = new Set<string>();
    for (const item of catalogItems) {
      const rid = item.restaurant_id?.trim();
      if (rid) ids.add(rid);
    }
    return [...ids];
  }, [catalogItems]);

  useEffect(() => {
    if (!location || restaurantIds.length === 0) {
      setFeesByRestaurantId({});
      return;
    }

    let cancelled = false;

    fetch('/api/public/app-offer-delivery', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        customer_latitude: location.latitude,
        customer_longitude: location.longitude,
        restaurant_ids: restaurantIds,
      }),
    })
      .then(async (res) => {
        const payload = await res.json();
        if (cancelled) return;
        if (payload?.success && payload.data?.feesByRestaurantId) {
          setFeesByRestaurantId(payload.data.feesByRestaurantId as Record<string, number>);
        } else {
          setFeesByRestaurantId({});
        }
      })
      .catch((error) => {
        console.warn('[AppExclusiveOffersSection] batch fees failed:', error);
        if (!cancelled) setFeesByRestaurantId({});
      });

    return () => {
      cancelled = true;
    };
  }, [location?.latitude, location?.longitude, restaurantIds]);

  const locationReady = Boolean(location && feeQuote.ready && !feeQuote.loading);

  const offers = useMemo(
    () =>
      buildAppOfferPreviews(catalogItems, {
        pageRestaurantId: restaurantId,
        promos,
        feesByRestaurantId,
        locationReady,
      }),
    [catalogItems, restaurantId, promos, feesByRestaurantId, locationReady],
  );

  const maxDiscount = useMemo(() => {
    const values = offers
      .map((o) => o.discountPercent)
      .filter((v): v is number => v != null && v > 0);
    return values.length ? Math.max(...values) : null;
  }, [offers]);

  if (!offersLoaded) {
    return null;
  }

  if (offers.length === 0) {
    return null;
  }

  const locationHint = !location
    ? ar.appOfferLocationCta
    : feeQuote.loading || locationLoading
      ? ar.feeLoading
      : null;

  return (
    <>
      <AppOfferWaveSection inline={inline}>
        <div className="mb-3 flex items-start justify-between gap-2">
          <div className="min-w-0 flex-1">
            <div className="flex flex-wrap items-center gap-2">
              <h2 className="text-[15px] font-bold text-gray-900">
                {ar.appExclusiveOffersTitle}
              </h2>
              {maxDiscount != null ? (
                <span className="rounded-full bg-emerald-600 px-2 py-0.5 text-[10px] font-bold text-white">
                  خصم حتى {maxDiscount}%
                </span>
              ) : null}
            </div>
            {locationHint ? (
              <button
                type="button"
                onClick={onRequestLocation}
                className="mt-1 text-start text-[11px] font-medium text-orange-700 underline-offset-2 hover:underline"
              >
                {locationHint}
              </button>
            ) : null}
          </div>
        </div>

        <div className="relative -mx-4">
          <div className="overflow-x-auto snap-x snap-mandatory scroll-ps-4 scroll-pe-4 [scrollbar-width:none] [&::-webkit-scrollbar]:hidden">
            <div className="flex w-max min-w-full gap-2.5 px-4 pb-1">
              {offers.map((offer) => (
                <AppOfferPreviewCard
                  key={offer.id}
                  offer={offer}
                  onTap={() => setSelected(offer)}
                />
              ))}
            </div>
          </div>
        </div>
      </AppOfferWaveSection>

      <AppOfferPreviewDialog
        offer={selected}
        open={selected != null}
        onClose={() => setSelected(null)}
      />
    </>
  );
}
