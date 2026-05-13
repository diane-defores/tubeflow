const crypto = require('node:crypto');

const {
  YOUTUBE_SCOPE,
  getEnv,
  getRequestOrigin,
  isSecureOrigin,
  serializeCookie,
  sanitizeReturnTo,
} = require('./_youtube');

function sendJsonError(res, statusCode, message) {
  res.statusCode = statusCode;
  res.setHeader('Content-Type', 'application/json; charset=utf-8');
  res.end(JSON.stringify({ error: message }));
}

module.exports = async function handler(req, res) {
  if (req.method !== 'GET') {
    res.statusCode = 405;
    res.setHeader('Allow', 'GET');
    res.end('Method Not Allowed');
    return;
  }

  const origin = getRequestOrigin(req);
  const secure = isSecureOrigin(origin);
  const requestUrl = new URL(req.url, origin);
  const returnTo = sanitizeReturnTo(requestUrl.searchParams.get('return_to'));
  const authHeader = req.headers.authorization || '';
  const firebaseIdToken = authHeader.startsWith('Bearer ')
    ? authHeader.slice('Bearer '.length).trim()
    : '';
  const googleClientId = getEnv(
    'GOOGLE_CLIENT_ID',
    'NEXT_PUBLIC_GOOGLE_CLIENT_ID',
  );

  if (!googleClientId) {
    sendJsonError(
      res,
      500,
      'Google OAuth is not configured on this deployment.',
    );
    return;
  }

  if (!firebaseIdToken) {
    sendJsonError(res, 401, 'Missing Firebase auth token.');
    return;
  }

  const state = crypto.randomUUID();
  const redirectUri = new URL('/api/auth/youtube/callback', origin).toString();
  const authUrl = new URL('https://accounts.google.com/o/oauth2/v2/auth');

  authUrl.searchParams.set('client_id', googleClientId);
  authUrl.searchParams.set('redirect_uri', redirectUri);
  authUrl.searchParams.set('response_type', 'code');
  authUrl.searchParams.set('scope', YOUTUBE_SCOPE);
  authUrl.searchParams.set('access_type', 'offline');
  authUrl.searchParams.set('prompt', 'consent');
  authUrl.searchParams.set('include_granted_scopes', 'true');
  authUrl.searchParams.set('state', state);

  res.statusCode = 200;
  res.setHeader('Content-Type', 'application/json; charset=utf-8');
  res.setHeader('Set-Cookie', [
    serializeCookie('youtube_oauth_state', state, {
      path: '/',
      httpOnly: true,
      sameSite: 'Lax',
      secure,
      maxAge: 600,
    }),
    serializeCookie('youtube_oauth_return_to', returnTo, {
      path: '/',
      httpOnly: true,
      sameSite: 'Lax',
      secure,
      maxAge: 600,
    }),
    serializeCookie('tubeflow_youtube_firebase_id_token', firebaseIdToken, {
      path: '/',
      httpOnly: true,
      sameSite: 'Lax',
      secure,
      maxAge: 3000,
    }),
  ]);
  res.end(JSON.stringify({ authUrl: authUrl.toString() }));
};
