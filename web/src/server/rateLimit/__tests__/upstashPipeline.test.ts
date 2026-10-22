import { afterEach, describe, expect, it, vi } from 'vitest';
import { upstashPipelineIncrWithExpire } from '../upstashPipeline';
import {
  allowTrackingFetchByIp,
  allowTrackingFetchByTokenPrefix,
} from '../trackingLimiter';
import { allowTableScan } from '../upstashTableLimiter';

const ORIG_URL = process.env.UPSTASH_REDIS_REST_URL;
const ORIG_TOKEN = process.env.UPSTASH_REDIS_REST_TOKEN;

afterEach(() => {
  if (ORIG_URL === undefined) delete process.env.UPSTASH_REDIS_REST_URL;
  else process.env.UPSTASH_REDIS_REST_URL = ORIG_URL;
  if (ORIG_TOKEN === undefined) delete process.env.UPSTASH_REDIS_REST_TOKEN;
  else process.env.UPSTASH_REDIS_REST_TOKEN = ORIG_TOKEN;
  vi.unstubAllGlobals();
});

describe('upstashPipelineIncrWithExpire', () => {
  it('returns missing_env when Upstash unset', async () => {
    delete process.env.UPSTASH_REDIS_REST_URL;
    delete process.env.UPSTASH_REDIS_REST_TOKEN;
    const result = await upstashPipelineIncrWithExpire('k', 60);
    expect(result).toEqual({ ok: false, reason: 'missing_env' });
  });

  it('posts to /pipeline and reads incr result', async () => {
    process.env.UPSTASH_REDIS_REST_URL = 'https://example-upstash.test';
    process.env.UPSTASH_REDIS_REST_TOKEN = 'tok';

    const fetchMock = vi.fn().mockResolvedValue({
      ok: true,
      json: async () => [{ result: 3 }, { result: 1 }],
    });

    const result = await upstashPipelineIncrWithExpire('web:track:ip:1', 60, fetchMock as never);
    expect(result).toEqual({ ok: true, count: 3 });
    expect(fetchMock).toHaveBeenCalledWith(
      'https://example-upstash.test/pipeline',
      expect.objectContaining({ method: 'POST' }),
    );
    const body = JSON.parse(String((fetchMock.mock.calls[0]?.[1] as { body?: string })?.body));
    expect(body[0][0]).toBe('INCR');
    expect(body[1][0]).toBe('EXPIRE');
  });

  it('returns request_failed on non-OK', async () => {
    process.env.UPSTASH_REDIS_REST_URL = 'https://example-upstash.test';
    process.env.UPSTASH_REDIS_REST_TOKEN = 'tok';
    const fetchMock = vi.fn().mockResolvedValue({ ok: false, json: async () => ({}) });
    const result = await upstashPipelineIncrWithExpire('k', 60, fetchMock as never);
    expect(result).toEqual({ ok: false, reason: 'request_failed' });
  });
});

describe('trackingLimiter fail-closed', () => {
  it('allows when Upstash unset', async () => {
    delete process.env.UPSTASH_REDIS_REST_URL;
    delete process.env.UPSTASH_REDIS_REST_TOKEN;
    await expect(allowTrackingFetchByIp('1.1.1.1')).resolves.toBe(true);
  });

  it('denies when Upstash configured but broken', async () => {
    process.env.UPSTASH_REDIS_REST_URL = 'https://example-upstash.test';
    process.env.UPSTASH_REDIS_REST_TOKEN = 'tok';
    vi.stubGlobal(
      'fetch',
      vi.fn().mockResolvedValue({ ok: false, json: async () => ({}) }),
    );
    await expect(allowTrackingFetchByIp('1.1.1.1')).resolves.toBe(false);
    await expect(allowTrackingFetchByTokenPrefix('abcdefgh')).resolves.toBe(false);
  });

  it('enforces limit on success path', async () => {
    process.env.UPSTASH_REDIS_REST_URL = 'https://example-upstash.test';
    process.env.UPSTASH_REDIS_REST_TOKEN = 'tok';
    vi.stubGlobal(
      'fetch',
      vi.fn().mockResolvedValue({
        ok: true,
        json: async () => [{ result: 61 }, { result: 1 }],
      }),
    );
    await expect(allowTrackingFetchByIp('1.1.1.1')).resolves.toBe(false);
  });
});

describe('table limiter uses /pipeline', () => {
  it('calls /pipeline on allowTableScan when configured', async () => {
    process.env.UPSTASH_REDIS_REST_URL = 'https://example-upstash.test';
    process.env.UPSTASH_REDIS_REST_TOKEN = 'tok';
    const fetchMock = vi.fn().mockResolvedValue({
      ok: true,
      json: async () => [{ result: 1 }, { result: 1 }],
    });
    vi.stubGlobal('fetch', fetchMock);
    await expect(allowTableScan('9.9.9.9')).resolves.toBe(true);
    expect(String(fetchMock.mock.calls[0]?.[0])).toContain('/pipeline');
  });
});
