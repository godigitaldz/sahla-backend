-- Store QR path token for Performance admin display (service_role only; never exposed to clients).
ALTER TABLE public.restaurant_table_codes
  ADD COLUMN IF NOT EXISTS code_token uuid;

COMMENT ON COLUMN public.restaurant_table_codes.code_token IS
  'Plain UUID in /t/{token} URLs. Readable via service_role for admin QR printing only.';
