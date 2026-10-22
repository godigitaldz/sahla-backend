export type CreatedWebOrder = {
  id?: string;
  /** Customer-facing number — same as orders.order_number in DB (ORD-…). */
  order_number: string;
  public_order_code?: string;
  total_amount: number;
  fulfillment_type: string;
  restaurant_name: string;
  estimated_delivery_time?: number | null;
  idempotent?: boolean;
  duplicate_recovered?: boolean;
  /** Absolute secure tracking URL when Phase 1 tracking is enabled. */
  tracking_url?: string;
  /** Relative path for same-origin router.push. */
  tracking_path?: string;
};
