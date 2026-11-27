import { describe, expect, it } from 'vitest';
import {
  hasComplexStructure,
  validateMenuItemUpdate,
  type MenuItemDbSnapshot,
} from '../menuValidation';

describe('Staff Menu Item Mutation & Pricing Corruption Guards', () => {
  const pureScalarItem: MenuItemDbSnapshot = {
    id: 'item-1',
    restaurant_id: 'rest-1',
    name: 'Plain Pizza',
    price: 600,
    is_available: true,
    preparation_time: 15,
    variants: [],
    pricing_options: [],
    supplements: [],
    free_drinks_included: false,
    is_limited_offer: false,
  };

  const complexItemWithVariants: MenuItemDbSnapshot = {
    ...pureScalarItem,
    id: 'item-2',
    name: 'Pizza with Sizes',
    variants: [{ id: 'v1', name: 'Medium', price_adjustment: 0 }],
  };

  const complexItemWithLto: MenuItemDbSnapshot = {
    ...pureScalarItem,
    id: 'item-3',
    name: 'Flash Sale Burger',
    is_limited_offer: true,
  };

  it('detects complex structures correctly', () => {
    expect(hasComplexStructure(pureScalarItem)).toBe(false);
    expect(hasComplexStructure(complexItemWithVariants)).toBe(true);
    expect(hasComplexStructure(complexItemWithLto)).toBe(true);
  });

  describe('Direct Base Price Updates & Corruption Guard', () => {
    it('allows base price updates for pure scalar items', () => {
      const res = validateMenuItemUpdate(pureScalarItem, { price: 750 });
      expect(res.valid).toBe(true);
      if (res.valid) {
        expect(res.sanitizedPatch.price).toBe(750);
      }
    });

    it('blocks base price updates for items with variants to prevent corruption', () => {
      const res = validateMenuItemUpdate(complexItemWithVariants, { price: 750 });
      expect(res.valid).toBe(false);
      if (!res.valid) {
        expect(res.code).toBe('complex_item_price_edit_blocked');
      }
    });

    it('blocks base price updates for items with active LTO offers', () => {
      const res = validateMenuItemUpdate(complexItemWithLto, { price: 500 });
      expect(res.valid).toBe(false);
      if (!res.valid) {
        expect(res.code).toBe('complex_item_price_edit_blocked');
      }
    });

    it('rejects negative price values', () => {
      const res = validateMenuItemUpdate(pureScalarItem, { price: -50 });
      expect(res.valid).toBe(false);
      if (!res.valid) {
        expect(res.code).toBe('invalid_price');
      }
    });
  });

  describe('Scalar Fields (Availability & Prep Time)', () => {
    it('allows toggling is_available on both simple and complex items', () => {
      const resSimple = validateMenuItemUpdate(pureScalarItem, { is_available: false });
      expect(resSimple.valid).toBe(true);
      if (resSimple.valid) expect(resSimple.sanitizedPatch.is_available).toBe(false);

      const resComplex = validateMenuItemUpdate(complexItemWithVariants, { is_available: false });
      expect(resComplex.valid).toBe(true);
      if (resComplex.valid) expect(resComplex.sanitizedPatch.is_available).toBe(false);
    });

    it('validates preparation time between 1 and 300 minutes', () => {
      expect(validateMenuItemUpdate(pureScalarItem, { preparation_time: 20 }).valid).toBe(true);
      expect(validateMenuItemUpdate(pureScalarItem, { preparation_time: 0 }).valid).toBe(false);
      expect(validateMenuItemUpdate(pureScalarItem, { preparation_time: 350 }).valid).toBe(false);
      expect(validateMenuItemUpdate(pureScalarItem, { preparation_time: 15.5 }).valid).toBe(false);
    });
  });

  describe('Rejection of Forbidden Release 1 Mutations', () => {
    it('rejects payload attempts to modify variants or options', () => {
      const res = validateMenuItemUpdate(pureScalarItem, {
        variants: [{ name: 'Hack' }],
      } as any);
      expect(res.valid).toBe(false);
      if (!res.valid) {
        expect(res.code).toBe('complex_mutation_rejected');
      }
    });
  });
});
