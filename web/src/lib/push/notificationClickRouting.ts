/**
 * URL helpers for service worker notification click routing (testable in Node).
 */

export function normalizePathname(urlString: string): string {
  try {
    return new URL(urlString).pathname.replace(/\/+$/, '') || '/';
  } catch {
    return '';
  }
}

export function urlsMatch(clientUrl: string, targetLink: string): boolean {
  try {
    const client = new URL(clientUrl);
    const target = new URL(targetLink, client.origin);
    return (
      client.origin === target.origin &&
      normalizePathname(client.href) === normalizePathname(target.href)
    );
  } catch {
    return false;
  }
}

export function sameOrigin(clientUrl: string, targetLink: string): boolean {
  try {
    const client = new URL(clientUrl);
    const target = new URL(targetLink, client.origin);
    return client.origin === target.origin;
  } catch {
    return false;
  }
}

export type ClientWindow = { url: string; focus?: () => void; navigate?: (url: string) => Promise<void> };

/**
 * Resolve notification click action for tests (mirrors SW logic).
 */
export async function resolveNotificationClick(
  link: string,
  clientList: ClientWindow[],
  openWindow?: (url: string) => Promise<ClientWindow | null>,
): Promise<'focus_match' | 'navigate_focus' | 'open_window' | 'none'> {
  for (const client of clientList) {
    if (client.url && urlsMatch(client.url, link) && client.focus) {
      client.focus();
      return 'focus_match';
    }
  }
  for (const client of clientList) {
    if (client.url && sameOrigin(client.url, link) && client.navigate) {
      await client.navigate(link);
      client.focus?.();
      return 'navigate_focus';
    }
  }
  if (openWindow) {
    await openWindow(link);
    return 'open_window';
  }
  return 'none';
}
