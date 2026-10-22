'use client';

import { Fragment, useMemo, useRef, useState } from 'react';
import { useRouter, useSearchParams } from 'next/navigation';
import { SahlaBrandBanner } from '@/components/layout/SahlaBrandBanner';
import { MenuItemCard } from '@/components/menu/MenuItemCard';
import { MenuCategoryFilter } from '@/components/menu/MenuCategoryFilter';
import { DrinksSection } from '@/components/menu/DrinksSection';
import { MenuItemSheet, type SheetMenuItem } from '@/components/menu/MenuItemSheet';
import { CartReviewDrawer } from '@/components/cart/CartReviewDrawer';
import { FloatingCart } from '@/components/cart/FloatingCart';
import { CheckoutDrawer } from '@/components/checkout/CheckoutDrawer';
import { useWebCart } from '@/lib/cart/useWebCart';
import { catalogNameForLocale } from '@/lib/catalog';
import { ar } from '@/lib/i18n/ar';
import { buildMenuCategoryEntries } from '@/lib/menuCategoryMeta';
import {
  categoryDisplayName,
  categoryGroupKey,
  displayItemImage,
  expandVariantsToDisplayItems,
  itemDisplayName,
  partitionWebMenuItems,
  type RawPricing,
  type WebDisplayMenuItem,
} from '@/lib/menuCatalog';
import { RemoteImage } from '@/components/ui/RemoteImage';
import {
  RestaurantInfoPanel,
  type WebRestaurantProfile,
} from '@/components/restaurant/RestaurantInfoPanel';
import { useLiveRestaurantAvailability } from '@/lib/restaurant/useLiveRestaurantAvailability';
import { useCustomerLocation } from '@/lib/location/useCustomerLocation';
import { useDeliveryFeeQuote } from '@/lib/location/useDeliveryFeeQuote';
import { useTableSession } from '@/lib/table/useTableSession';
import { AppExclusiveOffersSection } from '@/components/restaurant/AppExclusiveOffersSection';

type Restaurant = WebRestaurantProfile;

type Props = {
  slug: string;
  restaurant: Restaurant;
  items: SheetMenuItem[];
};

function restaurantDisplayName(restaurant: Restaurant) {
  return catalogNameForLocale({
    rawName: restaurant.name,
    arabicName: restaurant.name_ar,
    latinName: restaurant.name_latin,
    languageCode: 'ar',
  });
}

function firstPricingOption(drink: SheetMenuItem): RawPricing | undefined {
  return Array.isArray(drink.pricing_options)
    ? (drink.pricing_options[0] as RawPricing | undefined)
    : undefined;
}

export function RestaurantMenuClient({ slug, restaurant, items }: Props) {
  const router = useRouter();
  const searchParams = useSearchParams();
  const tableQuery = searchParams.get('table') === '1';
  const { session: tableSession } = useTableSession();
  const isTableMode =
    tableQuery &&
    tableSession.status === 'active' &&
    tableSession.restaurantSlug === slug;
  const tableSessionExpired =
    tableQuery && (tableSession.status === 'expired' || tableSession.status === 'missing');
  const { cart, itemCount, subtotal, addItem, clearCart, updateLineQuantity, removeLine } =
    useWebCart(slug);
  const [activeItem, setActiveItem] = useState<WebDisplayMenuItem | null>(null);
  const [cartOpen, setCartOpen] = useState(false);
  const [checkoutOpen, setCheckoutOpen] = useState(false);
  const [selectedCategoryKey, setSelectedCategoryKey] = useState<string | null>(null);
  const sectionRefs = useRef<Record<string, HTMLElement | null>>({});

  const { food, drinks } = useMemo(() => partitionWebMenuItems(items), [items]);
  const foodCards = useMemo(() => expandVariantsToDisplayItems(food), [food]);
  const restaurantName = restaurantDisplayName(restaurant);
  const { orderBlockMessage, bump: bumpAvailability } = useLiveRestaurantAvailability(restaurant);
  const {
    location: customerLocation,
    loading: locationLoading,
    error: locationError,
    requestLocation,
  } = useCustomerLocation(slug);
  const feeQuote = useDeliveryFeeQuote(isTableMode ? null : slug, isTableMode ? null : customerLocation);

  const categoryEntries = useMemo(
    () => buildMenuCategoryEntries([...food, ...drinks]),
    [food, drinks],
  );

  const grouped = useMemo(() => {
    const map = new Map<string, { label: string; items: WebDisplayMenuItem[] }>();
    for (const item of foodCards) {
      const key = categoryGroupKey(item);
      const label = categoryDisplayName(item);
      if (!map.has(key)) {
        map.set(key, { label, items: [] });
      }
      map.get(key)!.items.push(item);
    }
    return [...map.values()];
  }, [foodCards]);

  const visibleGroups = useMemo(() => {
    if (!selectedCategoryKey) return grouped;
    return grouped.filter((group) => {
      const sample = group.items[0];
      return sample ? categoryGroupKey(sample) === selectedCategoryKey : false;
    });
  }, [grouped, selectedCategoryKey]);

  const showDrinks = drinks.length > 0;

  const handleCategorySelect = (key: string | null) => {
    setSelectedCategoryKey(key);
    if (key) {
      requestAnimationFrame(() => {
        sectionRefs.current[key]?.scrollIntoView({ behavior: 'smooth', block: 'start' });
      });
    }
  };

  const addDrinkToCart = (drink: SheetMenuItem, quantity: number) => {
    const firstPricing = firstPricingOption(drink);
    const unitPrice = Number(drink.price ?? firstPricing?.price ?? 0);
    addItem(
      {
        restaurantId: restaurant.id,
        restaurantSlug: slug,
        restaurantName,
      },
      {
        id: `${drink.id}:drink:${firstPricing?.size ?? 'default'}`,
        menu_item_id: drink.id,
        name: itemDisplayName(drink),
        image: displayItemImage({ ...drink, list_key: drink.id }),
        quantity,
        unit_price: unitPrice,
        total_price: Math.round(unitPrice * quantity * 100) / 100,
        pricing_size: firstPricing?.size ?? null,
        variant_name: null,
        supplement_names: [],
        special_instructions: null,
      },
    );
  };

  return (
    <div className="min-h-screen bg-white pb-28">
      <SahlaBrandBanner />

      <header className="px-4 pb-1 pt-5 text-center">
        {restaurant.logo_url ? (
          <div className="mx-auto mb-3 flex h-24 w-24 items-center justify-center overflow-hidden rounded-full border-4 border-white bg-white shadow-lg">
            <RemoteImage
              src={restaurant.logo_url}
              alt={restaurantName}
              width={96}
              height={96}
              className="h-full w-full object-cover"
            />
          </div>
        ) : null}
        <h1 className="text-2xl font-bold text-black">{ar.ourMenu}</h1>
        <p className="mt-1 text-sm text-gray-500">{restaurantName}</p>
        <RestaurantInfoPanel
          restaurant={restaurant}
          statusMessage={orderBlockMessage}
          deliveryFee={feeQuote.deliveryFee}
          feeLoading={feeQuote.loading}
          feeReady={feeQuote.ready}
          feeError={feeQuote.error}
          locationLoading={locationLoading}
          onRequestLocation={requestLocation}
          tableMode={isTableMode}
          tableNumber={isTableMode ? tableSession.tableNumber : null}
          tableLabel={isTableMode ? tableSession.tableLabel : null}
        />
      </header>

      <main className="px-4">
        {categoryEntries.length > 0 ? (
          <div className="mb-7 mt-6">
            <MenuCategoryFilter
              categories={categoryEntries}
              selectedKey={selectedCategoryKey}
              onSelect={handleCategorySelect}
            />
          </div>
        ) : null}

        {visibleGroups.map(({ label, items: categoryItems }, groupIndex) => {
          const sectionKey = categoryItems[0] ? categoryGroupKey(categoryItems[0]) : label;
          const categorySection = (
            <section
              key={label}
              ref={(node) => {
                sectionRefs.current[sectionKey] = node;
              }}
              className="mb-5 scroll-mt-36"
            >
              <h2 className="mb-2 text-start text-base font-semibold text-gray-900">{label}</h2>
              <div className="overflow-hidden rounded-2xl border border-gray-100 bg-white px-3 shadow-[0_4px_20px_rgba(0,0,0,0.06)]">
                {categoryItems.map((item) => (
                  <MenuItemCard
                    key={item.list_key}
                    item={item}
                    onTap={() => setActiveItem(item)}
                  />
                ))}
              </div>
            </section>
          );

          if (groupIndex !== 0) {
            return categorySection;
          }

          return (
            <Fragment key={label}>
              {categorySection}
              <AppExclusiveOffersSection
                slug={slug}
                restaurantId={restaurant.id}
                location={customerLocation}
                feeQuote={feeQuote}
                locationLoading={locationLoading}
                onRequestLocation={requestLocation}
                inline
              />
            </Fragment>
          );
        })}

        {visibleGroups.length === 0 ? (
          <AppExclusiveOffersSection
            slug={slug}
            restaurantId={restaurant.id}
            location={customerLocation}
            feeQuote={feeQuote}
            locationLoading={locationLoading}
            onRequestLocation={requestLocation}
            inline
          />
        ) : null}

        {showDrinks ? <DrinksSection drinks={drinks} onAdd={addDrinkToCart} /> : null}
      </main>

      <FloatingCart count={itemCount} onOpenCheckout={() => setCartOpen(true)} />

      <CartReviewDrawer
        open={cartOpen}
        restaurantName={restaurantName}
        items={cart?.items ?? []}
        subtotal={subtotal}
        onClose={() => setCartOpen(false)}
        onProceed={() => {
          bumpAvailability();
          setCartOpen(false);
          setCheckoutOpen(true);
        }}
        onUpdateQuantity={updateLineQuantity}
        onRemoveLine={removeLine}
      />

      {activeItem ? (
        <MenuItemSheet
          item={activeItem}
          lockedVariantId={activeItem.locked_variant_id ?? null}
          open={Boolean(activeItem)}
          onClose={() => setActiveItem(null)}
          onAdd={({
            quantity,
            unitPrice,
            pricingSize,
            variantName,
            supplementNames,
            specialInstructions,
          }) => {
            addItem(
              {
                restaurantId: restaurant.id,
                restaurantSlug: slug,
                restaurantName,
              },
              {
                id: `${activeItem.id}:${variantName ?? activeItem.locked_variant_id ?? 'default'}:${pricingSize ?? 'default'}:${supplementNames.join(',')}`,
                menu_item_id: activeItem.id,
                name: itemDisplayName(activeItem),
                image: displayItemImage(activeItem),
                quantity,
                unit_price: unitPrice,
                total_price: Math.round(unitPrice * quantity * 100) / 100,
                pricing_size: pricingSize,
                variant_name: variantName,
                supplement_names: supplementNames,
                special_instructions: specialInstructions ?? null,
              },
            );
          }}
        />
      ) : null}

      <CheckoutDrawer
        open={checkoutOpen}
        slug={slug}
        restaurantName={restaurantName}
        items={cart?.items ?? []}
        subtotal={subtotal}
        orderBlockMessage={orderBlockMessage}
        customerLocation={isTableMode ? null : customerLocation}
        locationLoading={isTableMode ? false : locationLoading}
        locationError={isTableMode ? null : locationError}
        onRequestLocation={requestLocation}
        deliveryFee={isTableMode ? 0 : feeQuote.deliveryFee}
        feeLoading={isTableMode ? false : feeQuote.loading}
        feeReady={isTableMode ? true : feeQuote.ready}
        feeError={isTableMode ? null : feeQuote.error}
        tableMode={isTableMode}
        tableNumber={isTableMode ? tableSession.tableNumber : null}
        tableLabel={isTableMode ? tableSession.tableLabel : null}
        tableSessionExpired={tableSessionExpired}
        tableSessionMessage={
          tableSession.status === 'expired' ? tableSession.message : ar.tableOrderSessionExpired
        }
        onOpen={bumpAvailability}
        onClose={() => setCheckoutOpen(false)}
        onBack={() => {
          setCheckoutOpen(false);
          setCartOpen(true);
        }}
        onSuccess={(data) => {
          try {
            clearCart();
          } catch {
            /* Safari private mode may block localStorage */
          }
          setCheckoutOpen(false);
          setCartOpen(false);
          if (data.tracking_path) {
            router.push(data.tracking_path);
            return;
          }
          if (data.tracking_url) {
            window.location.assign(data.tracking_url);
            return;
          }
          const successUrl =
            `/restaurants/${slug}/success/${encodeURIComponent(data.order_number)}` +
            `?total=${data.total_amount}&type=${data.fulfillment_type}` +
            `&restaurant=${encodeURIComponent(data.restaurant_name)}` +
            `&eta=${data.estimated_delivery_time ?? ''}`;
          router.push(successUrl);
        }}
      />
    </div>
  );
}
