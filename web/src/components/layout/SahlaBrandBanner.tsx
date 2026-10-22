'use client';

import { ar } from '@/lib/i18n/ar';
import { SAHLA_APP_LINKS } from '@/lib/appLinks';

function AppStoreBadge({ href }: { href: string }) {
  return (
    <a
      href={href}
      target="_blank"
      rel="noopener noreferrer"
      dir="ltr"
      className="group flex h-11 min-w-0 flex-1 items-center gap-2.5 rounded-[10px] border border-[#1a1a1a] bg-[#111111] px-3 shadow-[0_2px_8px_rgba(0,0,0,0.18)] transition active:scale-[0.98] hover:bg-black"
    >
      <svg viewBox="0 0 24 24" className="h-[22px] w-[22px] shrink-0 fill-white" aria-hidden>
        <path d="M18.71 19.5c-.83 1.24-1.71 2.45-3.05 2.47-1.34.03-1.77-.79-3.29-.79-1.53 0-2 .77-3.27.82-1.31.05-2.3-1.32-3.14-2.53C4.25 17 2.94 12.45 4.7 9.39c.87-1.52 2.43-2.48 4.12-2.51 1.28-.02 2.5.87 3.29.87.78 0 2.26-1.07 3.8-.91.65.03 2.47.26 3.64 1.98-.09.06-2.17 1.28-2.15 3.81.03 3.02 2.65 4.03 2.68 4.04-.03.07-.42 1.44-1.38 2.83M13 3.5c.73-.83 1.94-1.46 2.94-1.5.13 1.17-.34 2.35-1.04 3.19-.69.85-1.83 1.51-2.95 1.42-.15-1.15.41-2.35 1.05-3.11z" />
      </svg>
      <span className="min-w-0 flex-1 text-left leading-none text-white">
        <span className="block text-[8px] font-medium uppercase tracking-[0.04em] text-white/80">
          Download on the
        </span>
        <span className="mt-0.5 block text-[15px] font-semibold tracking-[-0.02em]">
          App Store
        </span>
      </span>
    </a>
  );
}

function GooglePlayBadge({ href }: { href: string }) {
  return (
    <a
      href={href}
      target="_blank"
      rel="noopener noreferrer"
      dir="ltr"
      className="group flex h-11 min-w-0 flex-1 items-center gap-2.5 rounded-[10px] border border-[#1a1a1a] bg-[#111111] px-3 shadow-[0_2px_8px_rgba(0,0,0,0.18)] transition active:scale-[0.98] hover:bg-black"
    >
      <svg viewBox="0 0 24 24" className="h-[22px] w-[22px] shrink-0" aria-hidden>
        <path
          fill="#EA4335"
          d="M3.18 23.76c.39.22.87.27 1.3.14l12.08-7.01-2.57-2.57-10.81 9.44z"
        />
        <path
          fill="#FBBC04"
          d="M1.32 1.45C.99 1.93.81 2.53.81 3.18v17.64c0 .65.18 1.25.51 1.73l10.02-10.02L1.32 1.45z"
        />
        <path
          fill="#4285F4"
          d="M15.51 11.18l-2.57-2.57L1.32 22.55c.44.25.96.28 1.43.07l12.76-11.44z"
        />
        <path
          fill="#34A853"
          d="M23.19 11.66c-.38-.22-.81-.35-1.26-.35H3.18l12.33 12.33c.43.13.91.08 1.3-.14l7.38-4.28c.38-.22.63-.63.63-1.09 0-.46-.25-.87-.63-1.09z"
        />
      </svg>
      <span className="min-w-0 flex-1 text-left leading-none text-white">
        <span className="block text-[8px] font-medium uppercase tracking-[0.06em] text-white/80">
          Get it on
        </span>
        <span className="mt-0.5 block text-[15px] font-semibold tracking-[-0.02em]">
          Google Play
        </span>
      </span>
    </a>
  );
}

export function SahlaBrandBanner() {
  return (
    <header className="relative overflow-hidden border-b border-orange-100/80 bg-gradient-to-b from-[#FFF9F3] via-white to-white">
      <div
        className="pointer-events-none absolute -start-10 top-0 h-28 w-28 rounded-full bg-[#FB8C00] opacity-35 blur-3xl"
        aria-hidden
      />
      <div
        className="pointer-events-none absolute -end-8 bottom-0 h-20 w-20 rounded-full bg-[#E65100] opacity-20 blur-2xl"
        aria-hidden
      />

      <div className="relative mx-auto max-w-md px-4 py-4 pt-[max(0.875rem,env(safe-area-inset-top))] text-center">
        <p className="mx-auto max-w-sm text-[14px] font-semibold leading-relaxed text-gray-700">
          {ar.sahlaSlogan}
        </p>
        <p className="mt-2 text-[12px] font-medium text-gray-500">{ar.downloadCta}</p>

        <div className="mx-auto mt-3.5 flex max-w-[340px] gap-2.5">
          <GooglePlayBadge href={SAHLA_APP_LINKS.playStore} />
          <AppStoreBadge href={SAHLA_APP_LINKS.appStore} />
        </div>
      </div>
    </header>
  );
}
