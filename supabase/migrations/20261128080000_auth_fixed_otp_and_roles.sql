-- Add fixed_otp column to user_profiles and create auth_fixed_otps table
-- Supports role-based authentication with fixed OTP stored in DB only.

ALTER TABLE public.user_profiles 
ADD COLUMN IF NOT EXISTS fixed_otp TEXT;

CREATE TABLE IF NOT EXISTS public.auth_fixed_otps (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  phone TEXT NOT NULL UNIQUE,
  otp TEXT NOT NULL,
  role TEXT NOT NULL DEFAULT 'admin',
  name TEXT,
  is_active BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_user_profiles_fixed_otp_phone 
ON public.user_profiles (phone) 
WHERE fixed_otp IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_auth_fixed_otps_phone 
ON public.auth_fixed_otps (phone);

GRANT ALL ON TABLE public.auth_fixed_otps TO service_role;
