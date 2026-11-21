import { NextRequest, NextResponse } from 'next/server';

/**
 * Neutralized Next.js route handler.
 * Delegates exclusively to the canonical Express-served /open endpoint (public/open.html + download.js)
 * to ensure in-app browser isolation and single-source-of-truth behavior.
 */
export async function GET(request: NextRequest) {
  const host = request.headers.get('host') || 'sahla-backend.vercel.app';
  const searchParams = request.nextUrl.searchParams.toString();
  const query = searchParams ? `?${searchParams}` : '';
  
  return NextResponse.redirect(new URL(`/open${query}`, `https://${host}`), 302);
}
