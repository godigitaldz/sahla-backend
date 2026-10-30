import type { Metadata } from 'next';
import { Cairo } from 'next/font/google';
import './globals.css';

const cairo = Cairo({
  subsets: ['arabic', 'latin'],
  weight: ['400', '500', '600', '700', '800'],
  variable: '--font-cairo',
});

export const metadata: Metadata = {
  title: 'ساهلة — خلي في بلاصتك.. حنا نجيو لعندك!',
  description: 'ساهلة — تطبيق توصيل الطعام الجزائري الأول. خلي في بلاصتك.. حنا نجيو لعندك!',
  manifest: '/manifest.webmanifest',
  openGraph: {
    title: 'ساهلة — خلي في بلاصتك.. حنا نجيو لعندك!',
    description: 'ساهلة — تطبيق توصيل الطعام الجزائري الأول. خلي في بلاصتك.. حنا نجيو لعندك!',
    siteName: 'ساهلة (Sahla Delivery)',
    locale: 'ar_DZ',
    type: 'website',
  },
  twitter: {
    card: 'summary_large_image',
    title: 'ساهلة — خلي في بلاصتك.. حنا نجيو لعندك!',
    description: 'ساهلة — تطبيق توصيل الطعام الجزائري الأول. خلي في بلاصتك.. حنا نجيو لعندك!',
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
