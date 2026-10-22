const ALLOWED_ORIGINS = new Set([
  'https://sahla-delivery.com',
  'https://www.sahla-delivery.com',
  'http://localhost:3000',
  'http://127.0.0.1:3000',
]);

const ALLOWED_HOSTS = new Set([
  'sahla-delivery.com',
  'www.sahla-delivery.com',
  'localhost:3000',
  '127.0.0.1:3000',
]);

export function assertAllowedOrigin(request: Request): boolean {
  const origin = request.headers.get('origin');
  if (origin && ALLOWED_ORIGINS.has(origin)) return true;

  const referer = request.headers.get('referer');
  if (referer) {
    try {
      const url = new URL(referer);
      if (ALLOWED_ORIGINS.has(`${url.protocol}//${url.host}`)) return true;
    } catch {
      // ignore malformed referer
    }
  }

  // iOS Safari often omits Origin/Referer on same-site POST; trust Host + Sec-Fetch-Site.
  const secFetchSite = request.headers.get('sec-fetch-site');
  const host = request.headers.get('host');
  if (
    host &&
    ALLOWED_HOSTS.has(host) &&
    (secFetchSite === 'same-origin' || secFetchSite === 'same-site' || secFetchSite === 'none')
  ) {
    return true;
  }

  return process.env.NODE_ENV !== 'production';
}

export function assertCsrf(request: Request, csrfCookie: string | undefined): boolean {
  const header = request.headers.get('x-table-csrf');
  if (!header || !csrfCookie) return false;
  return header === csrfCookie;
}
