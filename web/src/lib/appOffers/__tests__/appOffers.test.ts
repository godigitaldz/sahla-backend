import { describe, expect, it } from 'vitest';
import { filterRestaurantAppOffers } from '@/lib/appOffers/filterRestaurantAppOffers';
import { mergeAppOffersCarousel } from '@/lib/appOffers/mergeAppOffersCarousel';
import {
  discountPercentForItem,
  isLtoCatalogRowVisible,
} from '@/lib/appOffers/lto';
import { isSpecialPack } from '@/lib/menuCatalog';
import {
  formatPackVariantNamesOnly,
  packVariantLabels,
  specialPackCardTitle,
} from '@/lib/appOffers/specialPackNaming';
import type { WebMenuItem } from '@/lib/menuCatalog';

const RESTAURANT_A = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa';
const RESTAURANT_B = 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb';

const baseItem = (overrides: Partial<WebMenuItem> = {}): WebMenuItem => ({
  id: 'item-1',
  restaurant_id: RESTAURANT_A,
  name: 'Burger',
  price: 800,
  image: 'https://example.com/burger.jpg',
  is_available: true,
  ...overrides,
});

describe('filterRestaurantAppOffers', () => {
  it('includes active LTO rows with image for this restaurant', () => {
    const items = filterRestaurantAppOffers(
      [
        baseItem({
          is_limited_offer: true,
          offer_start_at: new Date(Date.now() - 60_000).toISOString(),
          offer_end_at: new Date(Date.now() + 3_600_000).toISOString(),
        }),
      ],
      RESTAURANT_A,
    );
    expect(items).toHaveLength(1);
  });

  it('excludes offers from other restaurants', () => {
    const items = filterRestaurantAppOffers(
      [
        baseItem({
          restaurant_id: RESTAURANT_B,
          is_limited_offer: true,
          offer_end_at: new Date(Date.now() + 3_600_000).toISOString(),
        }),
      ],
      RESTAURANT_A,
    );
    expect(items).toHaveLength(0);
  });

  it('includes non-LTO special packs', () => {
    const items = filterRestaurantAppOffers(
      [
        baseItem({
          category: 'Special Pack',
          is_limited_offer: false,
        }),
      ],
      RESTAURANT_A,
    );
    expect(items).toHaveLength(1);
  });

  it('does not treat box category as special pack', () => {
    const item = baseItem({
      category: 'بوكس',
      category_name_ar: 'بوكس',
      is_limited_offer: false,
    });
    expect(isSpecialPack(item)).toBe(false);
    expect(filterRestaurantAppOffers([item], RESTAURANT_A)).toHaveLength(0);
  });

  it('excludes regular menu items', () => {
    const items = filterRestaurantAppOffers([baseItem()], RESTAURANT_A);
    expect(items).toHaveLength(0);
  });

  it('excludes items without image', () => {
    const items = filterRestaurantAppOffers(
      [
        baseItem({
          image: '',
          is_limited_offer: true,
          offer_end_at: new Date(Date.now() + 3_600_000).toISOString(),
        }),
      ],
      RESTAURANT_A,
    );
    expect(items).toHaveLength(0);
  });
});

describe('mergeAppOffersCarousel', () => {
  const lto = (id: string, restaurantId: string): WebMenuItem =>
    baseItem({
      id,
      restaurant_id: restaurantId,
      is_limited_offer: true,
      offer_end_at: new Date(Date.now() + 3_600_000).toISOString(),
    });

  it('places own restaurant offers before other wilayah offers', () => {
    const merged = mergeAppOffersCarousel(
      [lto('own-1', RESTAURANT_A)],
      [lto('other-1', RESTAURANT_B), lto('own-2', RESTAURANT_A)],
      RESTAURANT_A,
    );
    expect(merged.map((item) => item.id)).toEqual(['own-1', 'own-2', 'other-1']);
  });

  it('dedupes items already present in the restaurant menu', () => {
    const merged = mergeAppOffersCarousel(
      [lto('shared', RESTAURANT_A)],
      [lto('shared', RESTAURANT_A), lto('other', RESTAURANT_B)],
      RESTAURANT_A,
    );
    expect(merged.map((item) => item.id)).toEqual(['shared', 'other']);
  });
});

describe('specialPackNaming', () => {
  const packItem = (overrides: Partial<WebMenuItem> = {}): WebMenuItem => ({
    id: 'pack-1',
    restaurant_id: RESTAURANT_A,
    name: 'بوكس',
    name_ar: 'بوكس',
    category: 'Special Pack',
    price: 1000,
    image: 'https://example.com/pack.jpg',
    is_available: true,
    is_special_pack_catalog_row: true,
    variants: [
      {
        name: 'Tacos',
        name_ar: 'طاكوس',
        description: 'qty:1',
      },
      {
        name: 'Wrap',
        name_ar: 'ملفوف',
        description: 'qty:1',
      },
    ],
    ...overrides,
  });

  it('joins pack variant labels with plus like home cards', () => {
    const item = packItem();
    expect(isSpecialPack(item)).toBe(true);
    expect(packVariantLabels(item, 'ar')).toEqual(['طاكوس', 'ملفوف']);
    expect(formatPackVariantNamesOnly(item, 'ar')).toBe('طاكوس + ملفوف');
    expect(specialPackCardTitle(item, 'ar')).toBe('طاكوس + ملفوف');
  });

  it('uses stored offer name when variants are missing', () => {
    const item = packItem({
      name: 'عرض بيتزا 2 فصول Pizza et Fries',
      name_ar: 'عرض بيتزا 2 فصول',
      variants: [],
    });
    expect(specialPackCardTitle(item, 'ar')).toBe('عرض بيتزا 2 فصول');
  });
});

describe('isLtoCatalogRowVisible', () => {
  it('reads active window from pricing_options', () => {
    const item = baseItem({
      is_limited_offer: true,
      pricing_options: [
        {
          is_limited_offer: true,
          price: 600,
          original_price: 900,
          offer_types: ['special_price'],
          offer_start_at: new Date(Date.now() - 60_000).toISOString(),
          offer_end_at: new Date(Date.now() + 3_600_000).toISOString(),
        },
      ],
    });
    expect(isLtoCatalogRowVisible(item)).toBe(true);
    expect(discountPercentForItem(item)).toBe(11);
  });
});
