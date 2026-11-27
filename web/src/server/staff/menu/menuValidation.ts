/**
 * Staff Menu Item Mutation Validator & Release 1 Guards
 *
 * Enforces strict safety rules for menu edits in Release 1:
 * - Allowed scalar updates: `is_available` (boolean), `preparation_time` (1-300 min), and base `price`.
 * - Corruption Guard: Direct price updates are strictly blocked for items that contain variants,
 *   pricing options, supplements, pack components, or active Limited Time Offers (LTO).
 * - Complex nested mutations (variants, supplements, packs) are completely rejected in Release 1.
 */

export interface MenuItemDbSnapshot {
  id: string;
  restaurant_id: string;
  name: string;
  price: number;
  is_available: boolean;
  preparation_time?: number | null;
  variants?: unknown[] | null;
  pricing_options?: unknown[] | null;
  supplements?: unknown[] | null;
  free_drinks_included?: boolean | null;
  free_drinks_list?: unknown[] | null;
  is_limited_offer?: boolean | null;
  offer_start_at?: string | null;
  offer_end_at?: string | null;
}

export interface MenuItemPatchPayload {
  is_available?: boolean;
  preparation_time?: number;
  price?: number;
  // Disallowed fields to explicitly detect and reject
  variants?: unknown;
  pricing_options?: unknown;
  supplements?: unknown;
  is_limited_offer?: unknown;
  offer_types?: unknown;
  images?: unknown;
}

export type MenuValidationResult =
  | { valid: true; sanitizedPatch: { is_available?: boolean; preparation_time?: number; price?: number } }
  | {
      valid: false;
      code:
        | 'complex_mutation_rejected'
        | 'complex_item_price_edit_blocked'
        | 'invalid_price'
        | 'invalid_prep_time'
        | 'no_fields_to_update';
      message: string;
    };

export function hasComplexStructure(item: MenuItemDbSnapshot): boolean {
  if (Array.isArray(item.variants) && item.variants.length > 0) return true;
  if (Array.isArray(item.pricing_options) && item.pricing_options.length > 0) return true;
  if (Array.isArray(item.supplements) && item.supplements.length > 0) return true;
  if (item.free_drinks_included === true) return true;
  if (Array.isArray(item.free_drinks_list) && item.free_drinks_list.length > 0) return true;
  if (item.is_limited_offer === true) return true;
  return false;
}

export function validateMenuItemUpdate(
  item: MenuItemDbSnapshot,
  payload: MenuItemPatchPayload,
): MenuValidationResult {
  // 1. Explicitly reject forbidden nested mutations
  if (
    payload.variants !== undefined ||
    payload.pricing_options !== undefined ||
    payload.supplements !== undefined ||
    payload.is_limited_offer !== undefined ||
    payload.offer_types !== undefined ||
    payload.images !== undefined
  ) {
    return {
      valid: false,
      code: 'complex_mutation_rejected',
      message:
        'Complex menu structures (variants, supplements, pricing options, LTOs, images) cannot be edited directly in Release 1. Edits must use the canonical restaurant manager desktop workflow.',
    };
  }

  const sanitized: { is_available?: boolean; preparation_time?: number; price?: number } = {};
  let fieldCount = 0;

  // 2. Availability toggle
  if (typeof payload.is_available === 'boolean') {
    sanitized.is_available = payload.is_available;
    fieldCount++;
  }

  // 3. Preparation time
  if (payload.preparation_time !== undefined) {
    const pt = Number(payload.preparation_time);
    if (!Number.isInteger(pt) || pt < 1 || pt > 300) {
      return {
        valid: false,
        code: 'invalid_prep_time',
        message: 'Preparation time must be an integer between 1 and 300 minutes.',
      };
    }
    sanitized.preparation_time = pt;
    fieldCount++;
  }

  // 4. Base Price update & Corruption Guard
  if (payload.price !== undefined) {
    const price = Number(payload.price);
    if (!Number.isFinite(price) || price < 0) {
      return {
        valid: false,
        code: 'invalid_price',
        message: 'Price must be a valid non-negative number.',
      };
    }

    // Safety guard: If the item has complex structures (variants, pricing tiers, supplements, packs, LTOs),
    // changing the scalar base price will desynchronize the pricing model.
    if (hasComplexStructure(item)) {
      return {
        valid: false,
        code: 'complex_item_price_edit_blocked',
        message:
          'This item contains variants, options, supplements, or active offers. Direct base price updates are disabled to prevent menu data desynchronization.',
      };
    }

    sanitized.price = price;
    fieldCount++;
  }

  if (fieldCount === 0) {
    return {
      valid: false,
      code: 'no_fields_to_update',
      message: 'No valid update fields provided (allowed: is_available, preparation_time, price).',
    };
  }

  return { valid: true, sanitizedPatch: sanitized };
}
