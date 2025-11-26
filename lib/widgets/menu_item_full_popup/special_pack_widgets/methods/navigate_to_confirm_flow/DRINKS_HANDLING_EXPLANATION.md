# Unified Order Drinks Handler - How Paid and Free Drinks Are Handled

## Overview

The `UnifiedOrderDrinksHandler` class manages the complex scenario when both **current selections** and **saved orders** exist for LTO and regular items. It ensures drinks are properly categorized, priced, and distributed across cart items.

## Key Concepts

### 1. **Paid Drinks vs Free Drinks**

- **Free Drinks**: Included with the menu item (from `pricing.freeDrinksList`), have `price: 0` and `is_free: true`
- **Paid Drinks**: User-selected drinks that cost money, stored in `params.paidDrinkQuantities`, have actual prices

### 2. **Global vs Per-Item Drinks**

- **Paid Drinks**: **GLOBAL** - Added once to the entire order (only to the first cart item)
- **Free Drinks**: **PER-ITEM** - Each cart item gets its own free drinks (multiplied by item quantity)

## Method Breakdown

### 1. `calculateTotalPaidDrinksPrice()`

**Purpose**: Calculate the total price of all paid drinks globally.

**Logic**:

```dart
1. Calculate from current selections first (params.paidDrinkQuantities)
   - For each paid drink: price × quantity

2. Also check saved orders for paid drinks
   - Only add if NOT already in current selections (current takes precedence)
   - Prevents double-counting

3. Return total price (added only once to first item)
```

**Example**:

- Current: 1x Canette (150 DA) = 150 DA
- Saved: 1x Selecto (200 DA) = 200 DA (if not in current)
- **Total**: 150 DA (current takes precedence)

---

### 2. `mergePaidDrinkQuantities()`

**Purpose**: Merge paid drinks from saved orders with current selections.

**Logic**:

```dart
1. Get saved paid drinks from savedOrder['paid_drink_quantities']
2. Merge with current selections
3. Current selections OVERRIDE saved (current takes precedence)
```

**Example**:

- Saved: `{drink1: 2}`
- Current: `{drink1: 1, drink2: 1}`
- **Merged**: `{drink1: 1, drink2: 1}` (current overrides saved)

---

### 3. `calculateFreeDrinksForVariant()`

**Purpose**: Calculate free drinks for a specific variant (for current selections).

**Logic**:

```dart
For LTO/Regular Items:
  - Get base free drinks quantity from pricing (e.g., 1 per item)
  - Get free drink IDs from pricing.freeDrinksList
  - Multiply by variant quantity: baseQty × variantQuantity
  - Example: 1 free drink × 2 items = 2 free drinks

For Special Packs:
  - Use as-is (each pack gets its own free drinks)
```

**Example**:

- Pricing: `freeDrinksQuantity: 1`, `freeDrinksList: [drinkA, drinkB]`
- Variant quantity: 2
- User selected: `drinkA`
- **Result**: `{drinkA: 2}` (1 × 2 = 2)

---

### 4. `calculateFreeDrinksFromSavedOrder()`

**Purpose**: Calculate free drinks from a saved order (restoring saved state).

**Logic**:

```dart
For LTO/Regular Items (quantity > 1):
  - If savedOrder has 'free_drink_quantities' (preferred):
    - Multiply each by saved order quantity
    - Example: saved {drinkA: 1} × quantity 2 = {drinkA: 2}
  - Fallback: Use 'drink_quantities' and multiply all

For Special Packs or quantity = 1:
  - Use as-is (no multiplication)
```

**Example**:

- Saved order: `free_drink_quantities: {drinkA: 1}`, quantity: 2
- **Result**: `{drinkA: 2}` (multiplied by quantity)

---

### 5. `getDrinksPriceForItem()`

**Purpose**: Determine if paid drinks price should be added to this specific item.

**Logic**:

```dart
1. Check if this is the first item overall (isFirstItem)
2. Check if drinks were already added (drinksAlreadyAdded)
3. Only add price if: isFirstItem AND !drinksAlreadyAdded
4. Return price (or 0.0 if not first)
```

**Why**: Paid drinks are **GLOBAL** - only added once to the first item, not per item.

**Example**:

- Item 1: `isFirstItem: true, drinksAlreadyAdded: false` → Returns `150.0`
- Item 2: `isFirstItem: false` → Returns `0.0`

---

### 6. `mergeAllDrinkQuantities()`

**Purpose**: Combine free and paid drink quantities into a single map.

**Logic**:

```dart
1. If multiple variants AND not first variant:
   - Return empty map (drinks only in first variant)

2. Otherwise:
   - Combine free drinks + paid drinks
   - Both are included in quantities (even if price only added once)
```

**Why**: Quantities are needed for display, but price is only added once.

**Example**:

- Free: `{drinkA: 2}`
- Paid: `{drinkB: 1}`
- **Combined**: `{drinkA: 2, drinkB: 1}`

---

## Complete Flow Example

### Scenario: User has saved order + current selection

**Saved Order**:

- Item: Burger (qty: 2)
- Free drinks: `{Canette: 1}` per item → `{Canette: 2}` total
- Paid drinks: `{}` (none)

**Current Selection**:

- Paid drinks: `{Selecto: 1}` (150 DA)

**Handler Processing**:

1. **Calculate Total Paid Drinks Price**:

   - Current: 1 × 150 = 150 DA
   - Saved: none
   - **Total**: 150 DA

2. **Merge Paid Drink Quantities**:

   - Saved: `{}`
   - Current: `{Selecto: 1}`
   - **Merged**: `{Selecto: 1}`

3. **Calculate Free Drinks from Saved**:

   - Saved: `{Canette: 1}` per item
   - Quantity: 2
   - **Result**: `{Canette: 2}` (multiplied)

4. **Get Drinks Price for Item**:

   - First item: `150.0` (paid drinks price)
   - Second item: `0.0` (price already added)

5. **Merge All Drink Quantities**:
   - Free: `{Canette: 2}`
   - Paid: `{Selecto: 1}`
   - **Combined**: `{Canette: 2, Selecto: 1}`

**Final Cart Items**:

**Item 1** (Burger × 2):

- Price: basePrice + supplements + **150 DA** (paid drinks)
- Drink quantities: `{Canette: 2, Selecto: 1}`
- Customizations:
  - `free_drink_quantities`: `{Canette: 2}`
  - `paid_drink_quantities`: `{Selecto: 1}`

**Item 2** (if exists):

- Price: basePrice + supplements (no paid drinks)
- Drink quantities: `{Canette: 2}` (only free)
- Customizations:
  - `free_drink_quantities`: `{Canette: 2}`
  - `paid_drink_quantities`: `null`

---

## Key Rules

1. **Paid Drinks Are Global**:

   - Price added only once (to first item)
   - Quantities included in first item's customizations
   - Other items don't include paid drinks in price

2. **Free Drinks Are Per-Item**:

   - Each item gets its own free drinks
   - Multiplied by item quantity for LTO/regular items
   - Special packs: each pack gets its own free drinks

3. **Current Selections Take Precedence**:

   - If same drink in both saved and current, use current
   - Prevents conflicts and double-counting

4. **Separation for Display**:
   - `free_drink_quantities`: Separate map for free drinks
   - `paid_drink_quantities`: Separate map for paid drinks
   - `drink_quantities`: Combined map (for backward compatibility)

---

## Data Structure

```dart
// In customizations:
{
  'drinks': [
    // Free drinks
    {'id': 'drink1', 'price': 0.0, 'is_free': true},
    // Paid drinks
    {'id': 'drink2', 'price': 150.0, 'is_free': false},
  ],
  'drink_quantities': {
    'drink1': 2,  // Free
    'drink2': 1,  // Paid
  },
  'free_drink_quantities': {
    'drink1': 2,
  },
  'paid_drink_quantities': {
    'drink2': 1,
  },
}
```

---

## Debug Logging

The handler includes extensive debug logging:

- `🥤 UnifiedOrderDrinksHandler: Total paid drinks price`
- `🥤 UnifiedOrderDrinksHandler: Merging paid drinks quantities`
- `🥤 UnifiedOrderDrinksHandler: Calculating free drinks for variant`
- `🥤 UnifiedOrderDrinksHandler: Multiplying free drinks by quantity`
- `🥤 UnifiedOrderDrinksHandler: Adding paid drinks price to first item`
- `🥤 UnifiedOrderDrinksHandler: Merging all drink quantities`

Enable debug mode to see these logs in the console.
