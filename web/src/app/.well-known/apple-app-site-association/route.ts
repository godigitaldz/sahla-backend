import { NextResponse } from 'next/server';

const aasaPayload = {
  applinks: {
    apps: [],
    details: [
      {
        appIDs: [
          '9P628XCQ94.com.sahla.sahlaalgerie',
          '9P628XCQ94.com.godigital.sahla',
          'T8CTMB48BY.com.sahla.sahlaalgerie',
          'T8CTMB48BY.com.godigital.sahla'
        ],
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
    apps: [
      '9P628XCQ94.com.sahla.sahlaalgerie',
      '9P628XCQ94.com.godigital.sahla',
      'T8CTMB48BY.com.sahla.sahlaalgerie',
      'T8CTMB48BY.com.godigital.sahla'
    ]
  }
};

export async function GET() {
  return new NextResponse(JSON.stringify(aasaPayload, null, 2), {
    status: 200,
    headers: {
      'Content-Type': 'application/json; charset=utf-8',
      'Cache-Control': 'public, max-age=3600, s-maxage=3600',
      'Access-Control-Allow-Origin': '*'
    }
  });
}
