export const SAHLA_APP_LINKS = {
  appStore: process.env.NEXT_PUBLIC_APP_STORE_URL || '',
  playStore: process.env.NEXT_PUBLIC_PLAY_STORE_URL || 'https://play.google.com/store/apps/details?id=com.godigital.sahla',
} as const;
