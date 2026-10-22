import type { NextConfig } from 'next';

const nextConfig: NextConfig = {
  turbopack: {
    root: __dirname,
  },
  images: {
    remotePatterns: [
      { protocol: 'https', hostname: '**.supabase.co', pathname: '/**' },
      { protocol: 'https', hostname: 'wtowqpejzxlsmgywkjvn.supabase.co', pathname: '/**' },
      { protocol: 'https', hostname: '**.r2.dev', pathname: '/**' },
      { protocol: 'https', hostname: 'pub-011aba279eb84591b0d96b9b9415ce2e.r2.dev', pathname: '/**' },
      { protocol: 'https', hostname: 'pub-e75807f307834b89a8e0a2463ebb914f.r2.dev', pathname: '/**' },
      { protocol: 'https', hostname: 'images.unsplash.com', pathname: '/**' },
    ],
  },
};

export default nextConfig;
