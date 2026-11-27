/**
 * Safe Environment Guard
 * Strictly prevents automated test suites or local staging tools from communicating
 * with the production Supabase project (`wtowqpejzxlsmgywkjvn`).
 */

export const PRODUCTION_SUPABASE_REF = 'wtowqpejzxlsmgywkjvn';

export function isProductionDatabase(url?: string | null): boolean {
  if (!url) return false;
  return url.toLowerCase().includes(PRODUCTION_SUPABASE_REF);
}

export function assertSafeNonProduction(
  url?: string | null,
  context: string = 'Test or staging execution',
): void {
  if (isProductionDatabase(url)) {
    throw new Error(
      `[SECURITY HALT] ${context} attempted to target the production Supabase database (${PRODUCTION_SUPABASE_REF}). ` +
        `Automated tests and non-production runners are strictly prohibited from connecting to production.`,
    );
  }
}
