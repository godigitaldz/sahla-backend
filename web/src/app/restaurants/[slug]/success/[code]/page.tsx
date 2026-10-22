import { ar, formatDa } from '@/lib/i18n/ar';

type Props = {
  params: Promise<{ slug: string; code: string }>;
  searchParams: Promise<Record<string, string | string[] | undefined>>;
};

export default async function OrderSuccessPage({ params, searchParams }: Props) {
  const { slug, code } = await params;
  const query = await searchParams;

  const restaurantName = String(query.restaurant ?? 'المطعم');
  const fulfillmentType = String(query.type ?? 'delivery');
  const total = String(query.total ?? '');
  const eta = String(query.eta ?? '');

  return (
    <div className="flex min-h-screen flex-col items-center justify-center bg-white px-6 text-center">
      <div className="mb-4 text-5xl text-green-600">✓</div>
      <h1 className="text-2xl font-bold">{ar.orderSuccess}</h1>
      <p className="mt-2 text-sm text-gray-600">{ar.orderCode}</p>
      <p className="mt-1 text-3xl font-bold text-orange-600">{decodeURIComponent(code)}</p>

      <div className="mt-8 w-full max-w-md rounded-2xl border border-gray-100 bg-gray-50 p-4 text-right text-sm">
        <p>
          <span className="font-semibold">المطعم:</span> {decodeURIComponent(restaurantName)}
        </p>
        <p className="mt-2">
          <span className="font-semibold">نوع الطلب:</span>{' '}
          {fulfillmentType === 'pickup' ? ar.pickup : ar.delivery}
        </p>
        {total ? (
          <p className="mt-2">
            <span className="font-semibold">{ar.total}:</span> {formatDa(Number(total))}
          </p>
        ) : null}
        {eta ? (
          <p className="mt-2">
            <span className="font-semibold">الوقت المتوقع:</span> {eta} {ar.min}
          </p>
        ) : null}
      </div>

      <p className="mt-6 max-w-md text-sm leading-relaxed text-gray-600">
        سيقوم المطعم بتحضير طلبك وقد يتصل بك عند الحاجة.
      </p>

      <a
        href={`/restaurants/${slug}`}
        className="mt-8 rounded-full bg-orange-500 px-6 py-3 text-sm font-semibold text-white"
      >
        {ar.backToMenu}
      </a>
    </div>
  );
}
