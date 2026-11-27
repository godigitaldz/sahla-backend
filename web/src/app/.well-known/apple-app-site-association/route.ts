import { NextResponse } from 'next/server';

export async function GET() {
  const teamId = process.env.APPLE_TEAM_ID || 'TARGET_APPLE_TEAM_ID';
  const bundleId = process.env.APPLE_BUNDLE_ID || 'com.sahla.sahlaalgerie';
  const appId = `${teamId}.${bundleId}`;

  const aasaPayload = {
    applinks: {
      apps: [],
      details: [
        {
          appIDs: [appId],
          components: [
            { '/': '/open', comment: 'Matches /open path exactly' },
            { '/': '/open/*', comment: 'Matches all subpaths under /open' },
            { '/': '/download', comment: 'Matches /download' },
            { '/': '/download/*', comment: 'Matches all subpaths under /download' }
          ],
          paths: ['/open', '/open/*', '/download', '/download/*']
        }
      ]
    },
    webcredentials: {
      apps: [appId]
    }
  };

  return new NextResponse(JSON.stringify(aasaPayload, null, 2), {
    status: 200,
    headers: {
      'Content-Type': 'application/json; charset=utf-8',
      'Cache-Control': 'public, max-age=3600, s-maxage=3600',
      'Access-Control-Allow-Origin': '*'
    }
  });
}
