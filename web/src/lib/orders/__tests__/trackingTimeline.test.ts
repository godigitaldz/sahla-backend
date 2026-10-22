import { describe, expect, it } from 'vitest';
import {
  buildTrackingTimeline,
  isTerminalOrderStatus,
} from '@/lib/orders/trackingTimeline';

describe('buildTrackingTimeline', () => {
  it('maps delivery statuses onto four steps', () => {
    const pending = buildTrackingTimeline('pending', 'delivery');
    expect(pending.kind).toBe('delivery');
    expect(pending.current_step).toBe('placed');
    expect(pending.steps.map((s) => s.state)).toEqual([
      'current',
      'upcoming',
      'upcoming',
      'upcoming',
    ]);

    const preparing = buildTrackingTimeline('preparing', 'delivery');
    expect(preparing.current_step).toBe('preparing');
    expect(preparing.steps[1]?.state).toBe('current');

    const onWay = buildTrackingTimeline('picked_up', 'delivery');
    expect(onWay.current_step).toBe('on_the_way');

    const delivered = buildTrackingTimeline('delivered', 'delivery');
    expect(delivered.current_step).toBe('delivered');
    expect(delivered.terminal).toBe(true);
  });

  it('maps pickup/table statuses onto four steps', () => {
    const pending = buildTrackingTimeline('pending', 'pickup');
    expect(pending.kind).toBe('pickup_table');
    expect(pending.current_step).toBe('placed');

    const accepted = buildTrackingTimeline('confirmed', 'table');
    expect(accepted.current_step).toBe('accepted');

    const ready = buildTrackingTimeline('ready', 'pickup');
    expect(ready.current_step).toBe('ready');

    const collected = buildTrackingTimeline('collected', 'table');
    expect(collected.current_step).toBe('collected');
    expect(collected.terminal).toBe(true);
  });

  it('marks cancelled as terminal override', () => {
    const cancelled = buildTrackingTimeline('cancelled', 'delivery');
    expect(cancelled.cancelled).toBe(true);
    expect(cancelled.terminal).toBe(true);
    expect(cancelled.current_step).toBe('cancelled');
    expect(cancelled.steps.every((s) => s.state === 'complete' || s.state === 'skipped')).toBe(
      true,
    );
  });

  it('detects terminal statuses', () => {
    expect(isTerminalOrderStatus('delivered')).toBe(true);
    expect(isTerminalOrderStatus('collected')).toBe(true);
    expect(isTerminalOrderStatus('cancelled')).toBe(true);
    expect(isTerminalOrderStatus('preparing')).toBe(false);
  });
});
