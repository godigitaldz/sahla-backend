import { createHash, randomBytes, randomUUID } from 'crypto';

export function sha256Hex(input: string): string {
  return createHash('sha256').update(input).digest('hex');
}

export function sha256Buffer(input: string): Buffer {
  return createHash('sha256').update(input).digest();
}

export function generateSessionToken(): string {
  return randomBytes(32).toString('base64url');
}

export function generateCsrfToken(): string {
  return randomBytes(24).toString('base64url');
}

export function generateOpaqueTableCode(): string {
  return randomUUID();
}

export function generateVenueCode(): string {
  return String(Math.floor(100000 + Math.random() * 900000));
}
