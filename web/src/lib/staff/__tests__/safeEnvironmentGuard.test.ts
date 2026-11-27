import { describe, expect, it } from 'vitest';
import {
  assertSafeNonProduction,
  isProductionDatabase,
  PRODUCTION_SUPABASE_REF,
} from '../safeEnvironmentGuard';

describe('Safe Environment Guard', () => {
  it('correctly detects production database URLs', () => {
    expect(isProductionDatabase(`https://${PRODUCTION_SUPABASE_REF}.supabase.co`)).toBe(true);
    expect(isProductionDatabase(`postgresql://postgres:secret@db.${PRODUCTION_SUPABASE_REF}.supabase.co:5432/postgres`)).toBe(true);
  });

  it('correctly identifies non-production database URLs', () => {
    expect(isProductionDatabase('http://127.0.0.1:54321')).toBe(false);
    expect(isProductionDatabase('https://staging-test-ref.supabase.co')).toBe(false);
    expect(isProductionDatabase('')).toBe(false);
    expect(isProductionDatabase(null)).toBe(false);
  });

  it('throws a security halt when attempting to target production database', () => {
    expect(() =>
      assertSafeNonProduction(`https://${PRODUCTION_SUPABASE_REF}.supabase.co`, 'Integration Test Runner'),
    ).toThrowError(/\[SECURITY HALT\].*Integration Test Runner.*attempted to target the production Supabase database/);
  });

  it('allows safe non-production URLs without throwing', () => {
    expect(() =>
      assertSafeNonProduction('https://staging-project.supabase.co', 'Local Dev Test'),
    ).not.toThrow();
  });
});
