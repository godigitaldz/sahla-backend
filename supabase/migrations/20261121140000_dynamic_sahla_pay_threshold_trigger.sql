-- Migration: Dynamic Sahla Pay Threshold Trigger (2000 DA Cap)
-- Fixes hardcoded 1000 DA threshold in auto_generate_payment_on_tax_limit
-- Author: Sahla Systems Engineering
-- Date: 2026-11-21

BEGIN;

-- 1. Ensure system_config has sahla_pay_threshold_da set to 2000
INSERT INTO public.system_config (
  config_key,
  config_value,
  config_type,
  category,
  description,
  is_active
)
VALUES (
  'sahla_pay_threshold_da',
  '2000'::jsonb,
  'number',
  'fees',
  'Threshold in DA at which Sahla courier tax payment is auto-generated and courier is set offline',
  true
)
ON CONFLICT (config_key) DO UPDATE
SET config_value = COALESCE(public.system_config.config_value, '2000'::jsonb),
    is_active = true,
    updated_at = now();

-- 2. Update trigger function to dynamically check system_config_numeric('sahla_pay_threshold_da', 2000)
CREATE OR REPLACE FUNCTION public.auto_generate_payment_on_tax_limit()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $function$
DECLARE
  v_threshold numeric;
  v_payment_number text;
  v_unpaid_orders jsonb;
  v_unpaid_tasks jsonb;
  v_total_amount numeric(12, 2);
  v_existing_payment jsonb;
BEGIN
  -- Dynamic threshold from system_config (default 2000 DA)
  v_threshold := public.system_config_numeric('sahla_pay_threshold_da', 2000);

  -- Only proceed if sahla_tax reached or exceeded dynamic threshold
  IF NEW.sahla_tax >= v_threshold THEN
    v_existing_payment := NEW.tax_payment;

    -- If no existing payment or existing payment is not active (pending or auto_generated), create new one
    IF v_existing_payment IS NULL
       OR (v_existing_payment->>'status')::text NOT IN ('pending', 'auto_generated') THEN

      -- Get unpaid delivered/collected orders
      SELECT COALESCE(
        jsonb_agg(
          jsonb_build_object(
            'order_id', id,
            'order_number', order_number,
            'tax_amount', tax_amount,
            'delivery_tax', delivery_tax,
            'service_fee', service_fee,
            'total', COALESCE(tax_amount, 0) + COALESCE(delivery_tax, 0) + COALESCE(service_fee, 0)
          )
        ),
        '[]'::jsonb
      ) INTO v_unpaid_orders
      FROM public.orders
      WHERE delivery_person_id = NEW.id
        AND status IN ('delivered', 'collected')
        AND COALESCE(tax_paid, false) = false;

      -- Get unpaid completed tasks
      SELECT COALESCE(
        jsonb_agg(
          jsonb_build_object(
            'task_id', id,
            'delivery_tax', delivery_tax,
            'total', COALESCE(delivery_tax, 0)
          )
        ),
        '[]'::jsonb
      ) INTO v_unpaid_tasks
      FROM public.tasks
      WHERE delivery_man_id = NEW.user_id
        AND status = 'completed'
        AND COALESCE(tax_paid, false) = false;

      -- Generate payment number
      v_payment_number := 'SAHLA-' || EXTRACT(YEAR FROM NOW()) || '-' || LPAD(
        (EXTRACT(EPOCH FROM NOW())::bigint % 10000)::text,
        4,
        '0'
      );

      v_total_amount := NEW.sahla_tax;

      -- Create auto-generated payment record
      NEW.tax_payment := jsonb_build_object(
        'payment_number', v_payment_number,
        'status', 'auto_generated',
        'total_amount', v_total_amount,
        'receipt_url', NULL,
        'submitted_at', NULL,
        'auto_generated_at', NOW()::text,
        'orders', COALESCE(v_unpaid_orders, '[]'::jsonb),
        'tasks', COALESCE(v_unpaid_tasks, '[]'::jsonb)
      );

      -- Set is_online to false when payment is auto-generated
      NEW.is_online := false;

      RAISE NOTICE 'Auto-generated payment for delivery person %: Payment #% (amount % DA, threshold % DA)',
        NEW.id, v_payment_number, v_total_amount, v_threshold;
    END IF;
  END IF;

  RETURN NEW;
END;
$function$;

COMMENT ON FUNCTION public.auto_generate_payment_on_tax_limit() IS
  'Auto-generates tax_payment and sets is_online=false when sahla_tax reaches system_config.sahla_pay_threshold_da (default 2000 DA).';

-- 3. Replace the trigger without hardcoded 1000 DA in WHEN condition
DROP TRIGGER IF EXISTS trigger_auto_generate_payment_on_tax_limit ON public.delivery_personnel;

CREATE TRIGGER trigger_auto_generate_payment_on_tax_limit
BEFORE UPDATE ON public.delivery_personnel
FOR EACH ROW
WHEN (
  (old.sahla_tax IS DISTINCT FROM new.sahla_tax)
  AND (
    (new.tax_payment IS NULL)
    OR ((new.tax_payment ->> 'status'::text) <> ALL (ARRAY['pending'::text, 'auto_generated'::text]))
  )
)
EXECUTE FUNCTION public.auto_generate_payment_on_tax_limit();

-- 4. Cancel auto-generated payment SAHLA-2026-1408 and unblock courier Wail
UPDATE public.delivery_personnel
SET
  tax_payment = NULL,
  is_online = true,
  is_available = true,
  updated_at = NOW()
WHERE id = '82c428b2-d02b-4a8f-8d7d-9c5f1ae7a9e5'
  AND tax_payment->>'payment_number' = 'SAHLA-2026-1408';

COMMIT;
