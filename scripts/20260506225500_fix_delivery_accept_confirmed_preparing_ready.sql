-- Hotfix: allow courier acceptance for confirmed/preparing/ready orders.
-- Keeps first-accept-wins semantics and idempotent same-courier retries.

BEGIN;

CREATE OR REPLACE FUNCTION public.accept_order_by_delivery_person(
  p_order_id uuid,
  p_delivery_person_id uuid
)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_order_status text;
  v_existing_delivery_person_id uuid;
  v_delivery_person_id uuid;
BEGIN
  SELECT dp.id
  INTO v_delivery_person_id
  FROM public.delivery_personnel dp
  WHERE (dp.id = p_delivery_person_id OR dp.user_id = p_delivery_person_id)
    AND coalesce(dp.is_available, false) = true
    AND coalesce(dp.is_online, false) = true
  ORDER BY CASE WHEN dp.id = p_delivery_person_id THEN 0 ELSE 1 END
  LIMIT 1;

  IF v_delivery_person_id IS NULL THEN
    RETURN false;
  END IF;

  SELECT o.status, o.delivery_person_id
  INTO v_order_status, v_existing_delivery_person_id
  FROM public.orders o
  WHERE o.id = p_order_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN false;
  END IF;

  IF v_existing_delivery_person_id IS NOT NULL THEN
    RETURN v_existing_delivery_person_id = v_delivery_person_id;
  END IF;

  IF v_order_status NOT IN ('confirmed', 'preparing', 'ready') THEN
    RETURN false;
  END IF;

  UPDATE public.orders
  SET
    delivery_person_id = v_delivery_person_id,
    updated_at = now()
  WHERE id = p_order_id
    AND delivery_person_id IS NULL
    AND status IN ('confirmed', 'preparing', 'ready');

  RETURN FOUND;
END;
$$;

GRANT EXECUTE ON FUNCTION public.accept_order_by_delivery_person(uuid, uuid)
TO authenticated, service_role;

COMMIT;
