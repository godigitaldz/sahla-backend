'use client';

import { ar, formatDa } from '@/lib/i18n/ar';

function InfoBox({ label, value }: { label: string; value: string }) {
  return (
    <div className="flex min-w-0 flex-1 flex-col items-center justify-center px-1 text-center">
      <span className="text-[9px] font-semibold leading-tight text-gray-600">{label}</span>
      <span className="mt-0.5 text-[11px] font-bold leading-tight text-gray-900">{value}</span>
    </div>
  );
}

function Divider() {
  return <div className="mx-1 h-9 w-px shrink-0 bg-gray-200" aria-hidden />;
}

type Props = {
  tableNumber: string;
  tableLabel?: string | null;
  minimumOrder?: number;
  showMinimumOrder?: boolean;
  className?: string;
};

export function TableOrderInfoBox({
  tableNumber,
  tableLabel,
  minimumOrder = 0,
  showMinimumOrder = true,
  className = '',
}: Props) {
  const tableDisplay =
    tableLabel && tableLabel.trim()
      ? `${tableNumber} · ${tableLabel.trim()}`
      : tableNumber;

  return (
    <div
      className={`rounded-2xl border border-gray-200 bg-white px-2.5 py-3 shadow-[0_2px_10px_rgba(0,0,0,0.04)] ${className}`}
    >
      <div className="flex items-stretch">
        <InfoBox label={ar.tableOrderTableColumn} value={tableDisplay} />
        <Divider />
        <InfoBox label={ar.tableOrderTypeColumn} value={ar.tableOrderTypeValue} />
        {showMinimumOrder ? (
          <>
            <Divider />
            <InfoBox label={ar.minimumOrderLabel} value={formatDa(Math.max(0, minimumOrder))} />
          </>
        ) : null}
      </div>
    </div>
  );
}
