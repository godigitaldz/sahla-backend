import { NextRequest, NextResponse } from 'next/server';

/**
 * Neutralized Next.js route handler.
 * Delegates exclusively to the canonical Express-served /download endpoint (public/download.html + download.js)
 * preserving query strings.
 */
export async function GET(request: NextRequest) {
  const host = request.headers.get('host') || 'sahla-backend.vercel.app';
  const searchParams = request.nextUrl.searchParams.toString();
  const query = searchParams ? `?${searchParams}` : '';
  
  return NextResponse.redirect(new URL(`/download${query}`, `https://${host}`), 302);
}
