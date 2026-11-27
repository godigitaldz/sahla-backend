/**
 * Staff Username to Internal Alias Mapper
 *
 * Requirements:
 * - Staff users log in with their username.
 * - The backend maps the username to an internal, non-deliverable alias:
 *   e.g. `<username>@staff.sahla-delivery.com`.
 * - Zero Outbound Mail: Never display this alias to users or send mail/notifications to it.
 */

export const DEFAULT_ALIAS_DOMAIN = 'staff.sahla-delivery.com';

const USERNAME_REGEX = /^[a-zA-Z0-9][a-zA-Z0-9._-]{2,29}$/;

export function normalizeUsername(username: string): string {
  return String(username || '').trim().toLowerCase();
}

export function isValidUsername(username: string): { valid: boolean; reason?: string } {
  const normalized = normalizeUsername(username);
  if (!normalized) {
    return { valid: false, reason: 'Username is required.' };
  }
  if (normalized.length < 3) {
    return { valid: false, reason: 'Username must be at least 3 characters long.' };
  }
  if (normalized.length > 30) {
    return { valid: false, reason: 'Username cannot exceed 30 characters.' };
  }
  if (!USERNAME_REGEX.test(normalized)) {
    return {
      valid: false,
      reason:
        'Username must start with an alphanumeric character and contain only letters, numbers, dots, hyphens, or underscores.',
    };
  }
  return { valid: true };
}

const USERNAME_ALIASES: Record<string, string> = {
  hichem: 'hcihem',
};

export function usernameToInternalAlias(
  username: string,
  domain: string = DEFAULT_ALIAS_DOMAIN,
): string {
  const check = isValidUsername(username);
  if (!check.valid) {
    throw new Error(`Invalid username: ${check.reason}`);
  }
  const cleanDomain = domain.trim().toLowerCase();
  const normalized = normalizeUsername(username);
  const resolved = USERNAME_ALIASES[normalized] || normalized;
  return `${resolved}@${cleanDomain}`;
}

export function internalAliasToUsername(
  alias: string,
  domain: string = DEFAULT_ALIAS_DOMAIN,
): string | null {
  const cleanAlias = String(alias || '').trim().toLowerCase();
  const cleanDomain = domain.trim().toLowerCase();
  const suffix = `@${cleanDomain}`;
  if (!cleanAlias.endsWith(suffix)) {
    return null;
  }
  return cleanAlias.slice(0, -suffix.length);
}

export function isInternalAlias(
  email: string,
  domain: string = DEFAULT_ALIAS_DOMAIN,
): boolean {
  return internalAliasToUsername(email, domain) !== null;
}

/**
 * Hard safety check: Prevents any outbound email delivery system from sending
 * messages to the internal non-routable alias.
 */
export function assertNotAliasEmailRecipient(
  recipientEmail: string,
  domain: string = DEFAULT_ALIAS_DOMAIN,
): void {
  if (isInternalAlias(recipientEmail, domain)) {
    throw new Error(
      `[SECURITY VIOLATION] Attempted to dispatch an email to internal staff alias: "${recipientEmail}". ` +
        `All notifications, OTPs, and password reset tokens must route strictly to verified phone or external recovery email.`,
    );
  }
}
