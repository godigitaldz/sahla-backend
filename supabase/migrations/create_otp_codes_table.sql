-- Create OTP codes table for cost-effective OTP management
-- This replaces expensive Supabase Auth OTP with a custom solution using cheaper SMS APIs
create table if not exists public.otp_codes (
    id uuid not null default gen_random_uuid(),
    phone_number text not null,
    country_code text not null,
    full_phone text not null,
    code text not null,
    is_used boolean not null default false,
    expires_at timestamp with time zone not null,
    created_at timestamp with time zone not null default now(),
    verified_at timestamp with time zone null,
    constraint otp_codes_pkey primary key (id),
    constraint otp_codes_full_phone_code_idx unique (full_phone, code, is_used)
) TABLESPACE pg_default;
-- Index for active OTP lookups (unused and not expired)
create index if not exists idx_otp_codes_active on public.otp_codes using btree (full_phone, expires_at, is_used) TABLESPACE pg_default
where (is_used = false);
-- Index for cleanup of expired OTPs
create index if not exists idx_otp_codes_expires_at on public.otp_codes using btree (expires_at) TABLESPACE pg_default;
-- Enable RLS (Row Level Security)
alter table public.otp_codes enable row level security;
-- Policy: Allow service role to manage all OTPs
create policy "Service role can manage all OTPs" on public.otp_codes for all using (auth.jwt()->>'role' = 'service_role');
-- Policy: Allow users to verify their own OTPs (read-only for verification)
create policy "Users can verify their own OTPs" on public.otp_codes for
select using (true);
-- Allow read for verification, but actual verification happens in Edge Function
-- Function to clean up expired OTPs (can be called by a cron job)
create or replace function public.cleanup_expired_otps() returns integer language plpgsql security definer as $$
declare deleted_count integer;
begin
delete from public.otp_codes
where expires_at < now() - interval '24 hours';
get diagnostics deleted_count = row_count;
return deleted_count;
end;
$$;
-- Grant necessary permissions
grant usage on schema public to anon,
    authenticated;
grant select,
    insert,
    update on public.otp_codes to anon,
    authenticated;
grant execute on function public.cleanup_expired_otps() to service_role;
