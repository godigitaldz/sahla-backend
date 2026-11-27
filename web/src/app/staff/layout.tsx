import type { Metadata, Viewport } from 'next';

export const metadata: Metadata = {
  title: 'ساهلة — بوابة المطاعم والإدارة (Staff Portal)',
  description: 'بوابة إدارة الطلبات وقائمة الطعام لأصحاب المطاعم ومدراء ساهلة',
  manifest: '/staff-manifest.webmanifest',
  appleWebApp: {
    capable: true,
    statusBarStyle: 'default',
    title: 'Sahla Staff',
  },
  icons: {
    icon: '/favicon.ico',
    apple: '/favicon.ico',
  },
};

export const viewport: Viewport = {
  width: 'device-width',
  initialScale: 1,
  maximumScale: 1,
  userScalable: false,
  viewportFit: 'cover',
  themeColor: '#ffffff',
};

export default function StaffLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return (
    <div className="min-h-screen bg-slate-50 text-slate-900 flex flex-col font-sans selection:bg-orange-500 selection:text-white">
      {children}
    </div>
  );
}
