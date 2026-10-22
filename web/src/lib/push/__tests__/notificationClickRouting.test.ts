import { describe, expect, it } from 'vitest';
import {
  normalizePathname,
  resolveNotificationClick,
  sameOrigin,
  urlsMatch,
} from '@/lib/push/notificationClickRouting';

describe('notificationClickRouting', () => {
  const trackingUrl = 'https://www.sahla-delivery.com/restaurants/cafe/track/abc123token';

  it('urlsMatch compares origin and pathname', () => {
    expect(
      urlsMatch(
        'https://www.sahla-delivery.com/restaurants/cafe/track/abc123token',
        trackingUrl,
      ),
    ).toBe(true);
    expect(
      urlsMatch('https://www.sahla-delivery.com/restaurants/other/track/x', trackingUrl),
    ).toBe(false);
  });

  it('normalizePathname strips trailing slash', () => {
    expect(normalizePathname('https://x.com/a/b/')).toBe('/a/b');
  });

  it('sameOrigin matches host only', () => {
    expect(sameOrigin('https://www.sahla-delivery.com/menu', trackingUrl)).toBe(true);
    expect(sameOrigin('https://other.com/menu', trackingUrl)).toBe(false);
  });

  it('focuses matching client', async () => {
    let focused = false;
    const result = await resolveNotificationClick(trackingUrl, [
      {
        url: 'https://www.sahla-delivery.com/restaurants/cafe/track/abc123token',
        focus: () => {
          focused = true;
        },
      },
    ]);
    expect(result).toBe('focus_match');
    expect(focused).toBe(true);
  });

  it('navigates same-origin client when path differs', async () => {
    let navigatedTo = '';
    const result = await resolveNotificationClick(trackingUrl, [
      {
        url: 'https://www.sahla-delivery.com/',
        navigate: async (url: string) => {
          navigatedTo = url;
        },
        focus: () => {},
      },
    ]);
    expect(result).toBe('navigate_focus');
    expect(navigatedTo).toBe(trackingUrl);
  });

  it('opens window when no client matches', async () => {
    let opened = '';
    const result = await resolveNotificationClick(
      trackingUrl,
      [],
      async (url) => {
        opened = url;
        return { url };
      },
    );
    expect(result).toBe('open_window');
    expect(opened).toBe(trackingUrl);
  });
});
