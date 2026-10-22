'use client';

import type { ReactNode } from 'react';

type Props = {
  children: ReactNode;
  inline?: boolean;
};

const MINT_GRADIENT = 'linear-gradient(90deg, #F7FDFB 0%, #E3F6EF 42%, #BFE9D8 100%)';
const SECTION_GRADIENT =
  'linear-gradient(180deg, #EAF8F2 0%, #F0F7F4 14%, #F6ECEE 48%, #F8EDED 78%, #F8EDED 100%)';

function MintWaveTop() {
  return (
    <svg
      className="pointer-events-none absolute inset-x-0 top-0 h-[18px] w-full"
      viewBox="0 0 375 18"
      preserveAspectRatio="none"
      aria-hidden
    >
      <defs>
        <linearGradient id="app-offer-mint-wave" x1="0%" y1="0%" x2="100%" y2="0%">
          <stop offset="0%" stopColor="#F7FDFB" />
          <stop offset="42%" stopColor="#E3F6EF" />
          <stop offset="100%" stopColor="#BFE9D8" />
        </linearGradient>
      </defs>
      <path
        fill="url(#app-offer-mint-wave)"
        d="M0 0h375v2C312 14 228 18 187.5 18 147 18 63 14 0 2V0Z"
      />
    </svg>
  );
}

function WhiteWaveTop() {
  return (
    <svg
      className="pointer-events-none absolute inset-x-0 top-0 h-3 w-full text-white"
      viewBox="0 0 375 12"
      preserveAspectRatio="none"
      aria-hidden
    >
      <path
        fill="currentColor"
        d="M0 0h375v2C300 10 220 12 187.5 12 155 12 75 10 0 2V0Z"
      />
    </svg>
  );
}

function WaveBottom() {
  return (
    <svg
      className="pointer-events-none absolute inset-x-0 bottom-0 h-1.5 w-full text-white"
      viewBox="0 0 375 6"
      preserveAspectRatio="none"
      aria-hidden
    >
      <path
        fill="currentColor"
        d="M0 6V4C75 1 155 0 187.5 0 220 0 300 1 375 4v2H0Z"
      />
    </svg>
  );
}

/** Matches Flutter home LTO mint band + blush section shell. */
export function AppOfferWaveSection({ children, inline = false }: Props) {
  return (
    <section className={`relative -mx-4 overflow-hidden pb-4 ${inline ? 'mt-4' : 'mt-2'}`}>
      <WhiteWaveTop />
      <div
        className="relative overflow-hidden pb-4 pt-[18px]"
        style={{ background: SECTION_GRADIENT }}
      >
        <MintWaveTop />
        <div
          className="pointer-events-none absolute inset-x-0 top-0 h-[18px] opacity-90"
          style={{ background: MINT_GRADIENT }}
          aria-hidden
        />
        <WaveBottom />
        <div className="relative z-[1] px-4 pt-1">{children}</div>
      </div>
    </section>
  );
}
