/** Public Supabase project URL for storage assets (categories/cuisines icons). */
export const SUPABASE_PUBLIC_URL =
  process.env.NEXT_PUBLIC_SUPABASE_URL?.replace(/\/+$/, '') ??
  'https://wtowqpejzxlsmgywkjvn.supabase.co';

export function categoryIconPublicUrl(icon?: string | null): string | null {
  const raw = icon?.trim();
  if (!raw) return null;
  if (raw.startsWith('http://') || raw.startsWith('https://')) return raw;

  let path = raw.startsWith('/') ? raw.slice(1) : raw;
  if (path.startsWith('categories/')) {
    path = path.slice('categories/'.length);
  }
  if (!path) return null;
  return `${SUPABASE_PUBLIC_URL}/storage/v1/object/public/categories/${path}`;
}
