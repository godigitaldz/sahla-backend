import type { Metadata } from 'next';
import { TableScanClient } from '@/components/table/TableScanClient';

export const metadata: Metadata = {
  title: 'طلب من الطاولة — ساهلة',
  referrer: 'no-referrer',
  robots: { index: false, follow: false },
};

type Props = {
  params: Promise<{ tableCode: string }>;
};

export default async function TableScanPage({ params }: Props) {
  const { tableCode } = await params;
  return <TableScanClient tableCode={tableCode} />;
}
