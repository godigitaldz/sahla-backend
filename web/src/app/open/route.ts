import { NextRequest, NextResponse } from 'next/server';
import fs from 'fs';
import path from 'path';

/**
 * Next.js route handler for /open.
 * Directly serves public/open.html with text/html so any traffic routed to Next.js
 * immediately gets the canonical download gateway page without redirect loops.
 */
export async function GET(request: NextRequest) {
  try {
    const filePath = path.resolve(process.cwd(), 'public/open.html');
    if (fs.existsSync(filePath)) {
      const html = fs.readFileSync(filePath, 'utf8');
      return new NextResponse(html, {
        status: 200,
        headers: {
          'Content-Type': 'text/html; charset=utf-8',
          'Cache-Control': 'no-cache, must-revalidate',
        },
      });
    }
  } catch (_) {}
  
  const host = request.headers.get('host') || 'sahla-backend.vercel.app';
  const query = request.nextUrl.search || '';
  return NextResponse.redirect(new URL(`/open.html${query}`, `https://${host}`), 302);
}
