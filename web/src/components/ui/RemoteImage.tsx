'use client';

import { useState } from 'react';
import { ar } from '@/lib/i18n/ar';

type Props = {
  src?: string | null;
  alt: string;
  className?: string;
  width?: number;
  height?: number;
  fill?: boolean;
  priority?: boolean;
  fallbackClassName?: string;
};

export function RemoteImage({
  src,
  alt,
  className = '',
  width,
  height,
  fill,
  priority,
  fallbackClassName,
}: Props) {
  const [failed, setFailed] = useState(false);
  const url = src?.trim();

  if (!url || failed) {
    if (fill) {
      return (
        <div
          className={`absolute inset-0 flex items-center justify-center bg-gray-200 text-gray-400 ${fallbackClassName ?? className}`}
          aria-hidden={alt === ''}
        >
          <span className="text-2xl">🥤</span>
        </div>
      );
    }
    return (
      <div
        className={`flex items-center justify-center bg-gray-200 text-gray-400 ${fallbackClassName ?? className}`}
        style={fill ? undefined : { width, height }}
        aria-hidden={alt === ''}
      >
        <span className="text-2xl">🍽</span>
        <span className="sr-only">{ar.noImage}</span>
      </div>
    );
  }

  if (fill) {
    return (
      // eslint-disable-next-line @next/next/no-img-element
      <img
        src={url}
        alt={alt}
        className={`absolute inset-0 h-full w-full object-cover ${className}`}
        loading={priority ? 'eager' : 'lazy'}
        decoding="async"
        referrerPolicy="no-referrer"
        onError={() => setFailed(true)}
      />
    );
  }

  return (
    // eslint-disable-next-line @next/next/no-img-element
    <img
      src={url}
      alt={alt}
      width={width}
      height={height}
      className={className}
      loading={priority ? 'eager' : 'lazy'}
      decoding="async"
      referrerPolicy="no-referrer"
      onError={() => setFailed(true)}
    />
  );
}
