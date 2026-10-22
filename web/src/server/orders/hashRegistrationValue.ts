import { createHash } from 'crypto';

export function hashRegistrationValue(value: string): string {
  return createHash('sha256').update(value).digest('hex');
}
