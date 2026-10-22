'use client';

import { useState } from 'react';
import { SAHLA_COLORS } from '@/lib/theme';
import { SAHLA_APP_LINKS } from '@/lib/appLinks';
import { ar } from '@/lib/i18n/ar';

export function SahlaSidebar() {
  const [open, setOpen] = useState(false);

  return (
    <>
      <button
        type="button"
        aria-label="القائمة"
        onClick={() => setOpen(true)}
        className="fixed top-4 end-4 z-40 flex h-11 w-11 items-center justify-center rounded-full text-white shadow-lg"
        style={{ backgroundColor: SAHLA_COLORS.primary }}
      >
        <span className="text-xl leading-none">☰</span>
      </button>

      {open && (
        <div className="fixed inset-0 z-50 bg-black/40" onClick={() => setOpen(false)}>
          <aside
            className="absolute start-0 top-0 h-full w-[min(320px,88vw)] bg-white p-6 shadow-xl"
            onClick={(e) => e.stopPropagation()}
          >
            <div className="mb-6 flex items-center justify-between">
              <button type="button" onClick={() => setOpen(false)} aria-label={ar.close}>
                ✕
              </button>
              <h2 className="text-lg font-semibold" style={{ color: SAHLA_COLORS.primary }}>
                ساهلة
              </h2>
            </div>
            <p className="mb-4 text-sm leading-relaxed text-gray-600">{ar.sahlaTagline}</p>
            <div className="space-y-3 text-sm">
              <a
                href={SAHLA_APP_LINKS.appStore}
                className="block rounded-lg border px-4 py-3 text-center font-medium"
                target="_blank"
                rel="noreferrer"
              >
                {ar.downloadAppStore}
              </a>
              <a
                href={SAHLA_APP_LINKS.playStore}
                className="block rounded-lg border px-4 py-3 text-center font-medium"
                target="_blank"
                rel="noreferrer"
              >
                {ar.downloadPlayStore}
              </a>
              <a href="https://www.sahla-delivery.com" className="block text-center text-orange-600 underline">
                sahla-delivery.com
              </a>
            </div>
          </aside>
        </div>
      )}
    </>
  );
}
