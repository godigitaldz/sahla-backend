import type { Metadata } from 'next';
import { Cairo } from 'next/font/google';
import './globals.css';

const cairo = Cairo({
  subsets: ['arabic', 'latin'],
  weight: ['400', '500', '600', '700', '800'],
  variable: '--font-cairo',
});

export const metadata: Metadata = {
  title: 'ساهلة — اطلب أونلاين',
  description: 'اطلب من مطاعم ساهلة عبر الويب',
  manifest: '/manifest.webmanifest',
  openGraph: {
    title: 'ساهلة — اطلب أونلاين',
    description: 'اطلب من مطاعم ساهلة عبر الويب',
    siteName: 'ساهلة',
    locale: 'ar_DZ',
    type: 'website',
  },
  twitter: {
    card: 'summary_large_image',
    title: 'ساهلة — اطلب أونلاين',
    description: 'اطلب من مطاعم ساهلة عبر الويب',
  },
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="ar" dir="rtl" className={`${cairo.variable} h-full`}>
      <body className="min-h-full bg-white font-[family-name:var(--font-cairo)] text-black antialiased">
        {children}
      </body>
    </html>
  );
}
