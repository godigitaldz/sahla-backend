import type { SupabaseClient } from '@supabase/supabase-js';

export type WebCommissionConfig = {
  web_order_commission_rate: number;
  web_order_commission_cap_da: number;
  web_order_new_restaurant_commission_rate: number;
  web_order_new_restaurant_commission_cap_da: number;
};

export type RestaurantCommissionOverride = {
  is_new?: boolean;
  web_order_commission_rate?: number | null;
  web_order_commission_cap_da?: number | null;
};

export type WebCommissionResult = {
  taxAmount: number;
  rateUsed: number;
  capUsed: number;
  configSource: 'restaurant_override' | 'system_config_new' | 'system_config' | 'default_zero';
};

function roundMoney(value: number): number {
  return Math.round(value * 100) / 100;
}

export function resolveWebCommissionTax(args: {
  subtotal: number;
  restaurant: RestaurantCommissionOverride;
  systemConfig: WebCommissionConfig;
}): WebCommissionResult {
  const subtotal = Math.max(args.subtotal, 0);
  let rate = 0;
  let cap = 0;
  let configSource: WebCommissionResult['configSource'] = 'default_zero';

  if (args.restaurant.web_order_commission_rate != null) {
    rate = Number(args.restaurant.web_order_commission_rate) || 0;
    cap = Number(args.restaurant.web_order_commission_cap_da ?? 0) || 0;
    configSource = 'restaurant_override';
  } else if (args.restaurant.is_new) {
    rate = args.systemConfig.web_order_new_restaurant_commission_rate || 0;
    cap = args.systemConfig.web_order_new_restaurant_commission_cap_da || 0;
    configSource = 'system_config_new';
  } else {
    rate = args.systemConfig.web_order_commission_rate || 0;
    cap = args.systemConfig.web_order_commission_cap_da || 0;
    configSource = rate > 0 || cap > 0 ? 'system_config' : 'default_zero';
  }

  let taxAmount = roundMoney(subtotal * Math.max(rate, 0));
  if (cap > 0 && taxAmount > cap) {
    taxAmount = cap;
  }

  return { taxAmount, rateUsed: rate, capUsed: cap, configSource };
}

export async function loadWebCommissionConfig(
  admin: SupabaseClient,
): Promise<WebCommissionConfig> {
  const keys = [
    'web_order_commission_rate',
    'web_order_commission_cap_da',
    'web_order_new_restaurant_commission_rate',
    'web_order_new_restaurant_commission_cap_da',
  ];

  const { data } = await admin.from('system_config').select('config_key, config_value').in('config_key', keys);
  const map = new Map((data ?? []).map((row) => [row.config_key, Number(row.config_value) || 0]));

  return {
    web_order_commission_rate: map.get('web_order_commission_rate') ?? 0,
    web_order_commission_cap_da: map.get('web_order_commission_cap_da') ?? 0,
    web_order_new_restaurant_commission_rate: map.get('web_order_new_restaurant_commission_rate') ?? 0,
    web_order_new_restaurant_commission_cap_da: map.get('web_order_new_restaurant_commission_cap_da') ?? 0,
  };
}
