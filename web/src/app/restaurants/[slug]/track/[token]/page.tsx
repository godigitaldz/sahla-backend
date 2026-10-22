import type { Metadata } from 'next';
import { OrderTrackingClient } from '@/components/tracking/OrderTrackingClient';
import { isWebOrderPushOperational } from '@/server/orders/pushFeatureFlag';

type Props = {
  params: Promise<{ slug: string; token: string }>;
};

export const dynamic = 'force-dynamic';

export async function generateMetadata(): Promise<Metadata> {
  return {
    title: 'تتبع الطلب — ساهلة',
    description: 'تتبع حالة طلبك',
    robots: {
      index: false,
      follow: false,
      googleBot: { index: false, follow: false },
    },
    referrer: 'no-referrer',
  };
}

export default async function OrderTrackingPage({ params }: Props) {
  const { slug, token } = await params;
  const pushEnabled = isWebOrderPushOperational();
  return (
    <OrderTrackingClient
      slug={decodeURIComponent(slug)}
      token={decodeURIComponent(token)}
      pushEnabled={pushEnabled}
    />
  );
}
