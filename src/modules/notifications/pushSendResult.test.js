import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import { dispatchLogDelivered, pushSendSucceeded, pushTotalSent } from './pushSendResult.js';

describe('pushSendSucceeded', () => {
  it('returns true when pushes were delivered', () => {
    assert.equal(pushSendSucceeded({ success: true, total_sent: 3 }), true);
  });

  it('returns false for edge duplicate dedupe with zero sends', () => {
    assert.equal(
      pushSendSucceeded({
        success: true,
        total_sent: 0,
        raw: { success: true, skipped: true, reason: 'all_target_users_duplicate' },
      }),
      false,
    );
  });

  it('returns true for intentional mute skip', () => {
    assert.equal(
      pushSendSucceeded({
        success: true,
        total_sent: 0,
        raw: { success: true, skipped: true, reason: 'all_target_users_muted_new_order_push' },
      }),
      true,
    );
  });
});

describe('dispatchLogDelivered', () => {
  it('returns false for duplicate dedupe with zero sends', () => {
    assert.equal(
      dispatchLogDelivered({
        total_sent: 0,
        raw: { reason: 'all_target_users_duplicate' },
      }),
      false,
    );
  });

  it('returns true when pushes were delivered', () => {
    assert.equal(dispatchLogDelivered({ total_sent: 2 }), true);
  });
});
