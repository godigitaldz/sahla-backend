/** Algerian dialer normalization (mirrors Flutter InputSanitizer.normalizePhoneForDialer). */
export function normalizePhoneForStorage(raw: string): string {
  let phone = raw.trim().replace(/\s+/g, '');

  if (phone.startsWith('00213')) {
    phone = `+213${phone.slice(5)}`;
  } else if (phone.startsWith('+2130')) {
    phone = `+213${phone.slice(5)}`;
  } else if (phone.startsWith('2130')) {
    phone = `+213${phone.slice(4)}`;
  } else if (phone.startsWith('213') && !phone.startsWith('+')) {
    phone = `+${phone}`;
  } else if (phone.startsWith('0') && phone.length >= 10) {
    phone = `+213${phone.slice(1)}`;
  } else if (/^[567]\d{8}$/.test(phone)) {
    phone = `+213${phone}`;
  } else if (!phone.startsWith('+') && phone.length >= 9) {
    phone = `+213${phone.replace(/^0+/, '')}`;
  }

  return phone;
}

export function isValidGuestPhone(raw: string): boolean {
  const normalized = normalizePhoneForStorage(raw);
  return /^\+213[567]\d{8}$/.test(normalized);
}
