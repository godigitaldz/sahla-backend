import { describe, expect, it } from 'vitest';
import {
  assertNotAliasEmailRecipient,
  DEFAULT_ALIAS_DOMAIN,
  internalAliasToUsername,
  isInternalAlias,
  isValidUsername,
  normalizeUsername,
  usernameToInternalAlias,
} from '../usernameAlias';

describe('Staff Username Alias Mapper', () => {
  it('normalizes usernames consistently', () => {
    expect(normalizeUsername('  Manager_01  ')).toBe('manager_01');
    expect(normalizeUsername('Admin.Chef')).toBe('admin.chef');
  });

  it('validates permitted username characters and length', () => {
    expect(isValidUsername('chef_1').valid).toBe(true);
    expect(isValidUsername('manager-biskra').valid).toBe(true);
    expect(isValidUsername('a').valid).toBe(false); // too short
    expect(isValidUsername('a'.repeat(35)).valid).toBe(false); // too long
    expect(isValidUsername('_chef').valid).toBe(false); // cannot start with symbol
    expect(isValidUsername('chef@home').valid).toBe(false); // @ forbidden
  });

  it('maps valid username to internal non-deliverable alias', () => {
    const alias = usernameToInternalAlias('Chef_Yacine');
    expect(alias).toBe(`chef_yacine@${DEFAULT_ALIAS_DOMAIN}`);
  });

  it('reverses alias to original username', () => {
    expect(internalAliasToUsername(`chef_yacine@${DEFAULT_ALIAS_DOMAIN}`)).toBe('chef_yacine');
    expect(internalAliasToUsername('external.user@gmail.com')).toBe(null);
  });

  it('identifies internal aliases accurately', () => {
    expect(isInternalAlias(`owner_amine@${DEFAULT_ALIAS_DOMAIN}`)).toBe(true);
    expect(isInternalAlias('real-person@yahoo.com')).toBe(false);
  });

  it('throws a security violation when outbound email is directed to an alias', () => {
    expect(() =>
      assertNotAliasEmailRecipient(`manager_1@${DEFAULT_ALIAS_DOMAIN}`),
    ).toThrowError(/\[SECURITY VIOLATION\].*Attempted to dispatch an email to internal staff alias/);

    expect(() =>
      assertNotAliasEmailRecipient('manager_personal@gmail.com'),
    ).not.toThrow();
  });
});
