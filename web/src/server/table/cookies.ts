export const TABLE_SESSION_COOKIE = 'sahla_table_session';
export const TABLE_CSRF_COOKIE = 'sahla_table_csrf';
export const TABLE_SESSION_PATH = '/api/public/table';
export const TABLE_SESSION_MAX_AGE_SEC = 30 * 60;

export function tableSessionCookieOptions(maxAgeSec = TABLE_SESSION_MAX_AGE_SEC) {
  return {
    httpOnly: true,
    secure: process.env.NODE_ENV === 'production',
    sameSite: 'strict' as const,
    path: TABLE_SESSION_PATH,
    maxAge: maxAgeSec,
  };
}

export function tableCsrfCookieOptions(maxAgeSec = TABLE_SESSION_MAX_AGE_SEC) {
  return {
    httpOnly: false,
    secure: process.env.NODE_ENV === 'production',
    sameSite: 'strict' as const,
    path: '/',
    maxAge: maxAgeSec,
  };
}
