import { NextRequest, NextResponse } from 'next/server';

export async function GET(request: NextRequest) {
  const userAgent = request.headers.get('user-agent') || '';
  const isIOS = /iPhone|iPad|iPod/i.test(userAgent);
  const isAndroid = /Android/i.test(userAgent);

  const searchParams = request.nextUrl.searchParams.toString();
  const query = searchParams ? `?${searchParams}` : '';
  const uriScheme = `sahla://open${query}`;
  const iosStoreUrl = 'https://apps.apple.com/dz/app/sahla-algerie/id6834895657';
  const androidPlayStore = 'https://play.google.com/store/apps/details?id=com.godigital.sahla';

  if (isIOS) {
    const html = `<!DOCTYPE html>
<html lang="ar" dir="rtl">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0, viewport-fit=cover">
  <meta name="apple-itunes-app" content="app-id=6834895657, app-argument=${uriScheme}">
  <title>جاري فتح تطبيق سهلة…</title>
  <style>
    * { box-sizing: border-box; margin: 0; padding: 0; }
    body {
      font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, "Cairo", sans-serif;
      display: flex; flex-direction: column; align-items: center; justify-content: center;
      min-height: 100vh; background: #fafafa; text-align: center; padding: 24px;
    }
    .card {
      background: #ffffff; border-radius: 20px; padding: 36px 24px; max-width: 380px; width: 100%;
      box-shadow: 0 10px 30px rgba(0,0,0,0.08); border: 1px solid rgba(0,0,0,0.06);
    }
    .spinner {
      width: 48px; height: 48px; border: 4px solid #f1f1f1; border-top: 4px solid #FEB405;
      border-radius: 50%; animation: spin 0.85s linear infinite; margin: 0 auto 20px;
    }
    @keyframes spin { 0% { transform: rotate(0deg); } 100% { transform: rotate(360deg); } }
    h1 { font-size: 22px; font-weight: 800; color: #111; margin-bottom: 8px; }
    p { font-size: 14px; color: #666; margin-bottom: 24px; line-height: 1.5; }
    .btn {
      display: flex; align-items: center; justify-content: center; width: 100%;
      background: #FEB405; color: #111; font-weight: 700; text-decoration: none;
      padding: 14px; border-radius: 12px; font-size: 16px; margin-bottom: 12px;
      transition: transform 0.15s ease;
    }
    .btn:active { transform: scale(0.98); }
    .btn-secondary { background: #111111; color: #ffffff; margin-bottom: 0; }
  </style>
</head>
<body>
  <div class="card">
    <div class="spinner"></div>
    <h1>جاري فتح تطبيق سهلة…</h1>
    <p>إذا لم يفتح التطبيق تلقائياً، اضغط على فتح التطبيق أدناه أو قم بتحميله من App Store.</p>
    <a href="${uriScheme}" class="btn" id="openBtn">فتح تطبيق سهلة</a>
    <a href="${iosStoreUrl}" class="btn btn-secondary">تحميل من App Store</a>
  </div>
  <script>
    // 1. Direct scheme execution
    window.location.href = "${uriScheme}";

    // 2. Lifecycle tracking to cancel fallback when app opens
    var start = Date.now();
    var appOpened = false;

    function cancelFallback() {
      appOpened = true;
      if (timer) clearTimeout(timer);
    }

    var timer = setTimeout(function() {
      var elapsed = Date.now() - start;
      if (!appOpened && !document.hidden && elapsed < 3500) {
        window.location.replace("${iosStoreUrl}");
      }
    }, 2200);

    window.addEventListener('pagehide', cancelFallback);
    window.addEventListener('blur', cancelFallback);
    document.addEventListener('visibilitychange', function() {
      if (document.hidden) cancelFallback();
    });
  </script>
</body>
</html>`;
    return new NextResponse(html, {
      status: 200,
      headers: {
        'Content-Type': 'text/html; charset=utf-8',
        'Cache-Control': 'no-cache, no-store, must-revalidate'
      }
    });
  }

  if (isAndroid) {
    const intentUrl = `intent://open${query}#Intent;scheme=sahla;package=com.godigital.sahla;S.browser_fallback_url=${encodeURIComponent(androidPlayStore)};end`;
    return NextResponse.redirect(intentUrl, 302);
  }

  // Desktop visitor: redirect to main website download section
  const host = request.headers.get('host') || 'sahla-backend.vercel.app';
  return NextResponse.redirect(new URL(`/#download${query}`, `https://${host}`), 302);
}
