import { describe, expect, it } from 'vitest';
import { parseDeliveryPreviewFee } from '../deliveryFeePreview';
import { resolveWebCommissionTax } from '../webCommissionResolver';
import { computeWebOrderTotals } from '../webOrderTotals';
import { priceCartLines } from '../menuLinePricing';

describe('parseDeliveryPreviewFee', () => {
  it('reads fee_da from preview fees array', () => {
    const payload = {
      success: true,
      data: {
        fees: [
          { restaurant_id: 'abc', fee_da: 250 },
          { restaurant_id: 'other', fee_da: 100 },
        ],
      },
    };
    expect(parseDeliveryPreviewFee(payload, 'abc', 0)).toBe(250);
    expect(parseDeliveryPreviewFee(payload, 'missing', 99)).toBe(99);
  });
});

describe('webCommissionResolver', () => {
  it('defaults to zero commission', () => {
    const result = resolveWebCommissionTax({
      subtotal: 1000,
      restaurant: { is_new: false },
      systemConfig: {
        web_order_commission_rate: 0,
        web_order_commission_cap_da: 0,
        web_order_new_restaurant_commission_rate: 0,
        web_order_new_restaurant_commission_cap_da: 0,
      },
    });
    expect(result.taxAmount).toBe(0);
  });

  it('uses system config when set', () => {
    const result = resolveWebCommissionTax({
      subtotal: 1000,
      restaurant: { is_new: false },
      systemConfig: {
        web_order_commission_rate: 0.1,
        web_order_commission_cap_da: 200,
        web_order_new_restaurant_commission_rate: 0,
        web_order_new_restaurant_commission_cap_da: 0,
      },
    });
    expect(result.taxAmount).toBe(100);
  });
});

describe('webOrderTotals', () => {
  it('pickup has no delivery or service fee', () => {
    const totals = computeWebOrderTotals({
      subtotal: 500,
      fulfillmentType: 'pickup',
      restaurant: { is_new: false },
      systemConfig: {
        web_order_commission_rate: 0,
        web_order_commission_cap_da: 0,
        web_order_new_restaurant_commission_rate: 0,
        web_order_new_restaurant_commission_cap_da: 0,
      },
    });
    expect(totals.serviceFee).toBe(0);
    expect(totals.deliveryFee).toBe(0);
    expect(totals.totalAmount).toBe(500);
  });

  it('delivery adds fee and tax without service fee', () => {
    const totals = computeWebOrderTotals({
      subtotal: 500,
      fulfillmentType: 'delivery',
      deliveryQuote: {
        originalDeliveryFee: 200,
        deliveryFee: 200,
        deliveryTax: 10,
        netDeliveryAmount: 190,
      },
      restaurant: { is_new: false },
      systemConfig: {
        web_order_commission_rate: 0,
        web_order_commission_cap_da: 0,
        web_order_new_restaurant_commission_rate: 0,
        web_order_new_restaurant_commission_cap_da: 0,
      },
    });
    expect(totals.serviceFee).toBe(0);
    expect(totals.totalAmount).toBe(700);
    expect(totals.deliveryTax).toBe(10);
  });
});

describe('menuLinePricing', () => {
  it('prices regular item from pricing option', () => {
    const { subtotal, pricedLines } = priceCartLines(
      [
        {
          id: '11111111-1111-1111-1111-111111111111',
          restaurant_id: '22222222-2222-2222-2222-222222222222',
          name: 'Burger',
          price: 100,
          is_available: true,
          pricing_options: [{ size: 'Regular', price: 450 }],
          supplements: [],
          variants: [],
        },
      ],
      [
        {
          menu_item_id: '11111111-1111-1111-1111-111111111111',
          quantity: 2,
          pricing_size: 'Regular',
        },
      ],
      '22222222-2222-2222-2222-222222222222',
    );
    expect(subtotal).toBe(900);
    expect(pricedLines[0].unit_price).toBe(450);
    expect(pricedLines[0].customizations).toMatchObject({
      size: 'Regular',
      pricing_size: 'Regular',
      variant: null,
      variant_name: null,
    });
  });

  it('rejects manipulated client price', () => {
    expect(() =>
      priceCartLines(
        [
          {
            id: '11111111-1111-1111-1111-111111111111',
            restaurant_id: '22222222-2222-2222-2222-222222222222',
            name: 'Burger',
            price: 100,
            is_available: true,
            pricing_options: [{ size: 'Regular', price: 450 }],
          },
        ],
        [
          {
            menu_item_id: '11111111-1111-1111-1111-111111111111',
            quantity: 1,
            client_unit_price: 1,
          },
        ],
        '22222222-2222-2222-2222-222222222222',
      ),
    ).toThrow('price_manipulation_rejected');
  });
});
