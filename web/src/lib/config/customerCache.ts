export function customerCacheWorkerBaseUrl(): string {
  return (
    process.env.CUSTOMER_CACHE_WORKER_BASE_URL?.trim() ||
    'https://sahla-customer-cache.khazanimohamedamin.workers.dev'
  );
}
