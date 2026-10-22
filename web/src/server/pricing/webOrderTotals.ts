import { resolveWebCommissionTax, type WebCommissionConfig, type RestaurantCommissionOverride } from './webCommissionResolver';

export type DeliveryFeeQuote = {
  originalDeliveryFee: number;
  deliveryFee: number;
  deliveryTax: number;
  netDeliveryAmount: number;
};

export type WebOrderTotals = {
  subtotal: number;
  originalDeliveryFee: number;
  deliveryFee: number;
  deliveryTax: number;
  netDeliveryAmount: number;
  commissionTax: number;
  serviceFee: number;
  totalAmount: number;
  net: number;
  commissionMeta: ReturnType<typeof resolveWebCommissionTax>;
};

function roundMoney(value: number): number {
  return Math.round(value * 100) / 100;
}

export function computeDeliveryTax(
  deliveryFee: number,
  deliveryTaxRate: number,
  deliveryTaxCapDa: number,
): number {
  let tax = deliveryFee * deliveryTaxRate;
  if (deliveryTaxCapDa > 0 && tax > deliveryTaxCapDa) tax = deliveryTaxCapDa;
  return roundMoney(tax);
}

export function computeWebOrderTotals(args: {
  subtotal: number;
  fulfillmentType: 'delivery' | 'pickup' | 'table';
  deliveryQuote?: DeliveryFeeQuote;
  restaurant: RestaurantCommissionOverride;
  systemConfig: WebCommissionConfig;
}): WebOrderTotals {
  const serviceFee = 0;
  const commissionMeta = resolveWebCommissionTax({
    subtotal: args.subtotal,
    restaurant: args.restaurant,
    systemConfig: args.systemConfig,
  });

  if (args.fulfillmentType === 'pickup' || args.fulfillmentType === 'table') {
    const totalAmount = roundMoney(args.subtotal);
    return {
      subtotal: args.subtotal,
      originalDeliveryFee: 0,
      deliveryFee: 0,
      deliveryTax: 0,
      netDeliveryAmount: 0,
      commissionTax: commissionMeta.taxAmount,
      serviceFee,
      totalAmount,
      net: roundMoney(totalAmount - commissionMeta.taxAmount),
      commissionMeta,
    };
  }

  const quote = args.deliveryQuote ?? {
    originalDeliveryFee: 0,
    deliveryFee: 0,
    deliveryTax: 0,
    netDeliveryAmount: 0,
  };

  const totalAmount = roundMoney(args.subtotal + quote.deliveryFee + serviceFee);
  // App parity: deliveryTax is platform share on the tariff — not added to customer total.
  const net = roundMoney(totalAmount - quote.deliveryFee - commissionMeta.taxAmount);

  return {
    subtotal: args.subtotal,
    originalDeliveryFee: quote.originalDeliveryFee,
    deliveryFee: quote.deliveryFee,
    deliveryTax: quote.deliveryTax,
    netDeliveryAmount: quote.netDeliveryAmount,
    commissionTax: commissionMeta.taxAmount,
    serviceFee,
    totalAmount,
    net,
    commissionMeta,
  };
}
