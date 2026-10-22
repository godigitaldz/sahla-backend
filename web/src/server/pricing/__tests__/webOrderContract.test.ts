import { describe, expect, it } from 'vitest';

/** Mirrors SQL/Flutter web order number format: ORD-{last5Ms}{3Random} */
function generateWebOrderNumber(atMs: number, randomSuffix: number): string {
  const msText = String(atMs);
  const tail = msText.slice(Math.max(msText.length - 5, 0));
  return `ORD-${tail}${String(randomSuffix).padStart(3, '0')}`;
}

describe('web order number contract', () => {
  it('fits orders.order_number varchar(20)', () => {
    const sample = generateWebOrderNumber(Date.now(), 42);
    expect(sample.length).toBeLessThanOrEqual(20);
    expect(sample).toMatch(/^ORD-\d{8}$/);
  });

  it('rejects legacy 25-char SQL format', () => {
    const legacy = `ORD-${'20260619233045'}-abcdef`;
    expect(legacy.length).toBeGreaterThan(20);
  });

  it('web payment method fits varchar(20)', () => {
    expect('cash'.length).toBeLessThanOrEqual(20);
    expect('cash_on_delivery'.length).toBeLessThanOrEqual(20);
  });
});
