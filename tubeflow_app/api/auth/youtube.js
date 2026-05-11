const crypto = require('node:crypto');

const {
  YOUTUBE_SCOPE,
  getEnv,
  getRequestOrigin,
  isSecureOrigin,
  parseCookies,
  serializeCookie,
  sanitizeReturnTo,
  buildReturnUrl,
  sendRedirect,
} = require('./_youtube');

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
  const cookies = parseCookies(req.headers.cookie);
  const sessionId = cookies.tubeflow_youtube_clerk_session_id;
  const googleClientId = getEnv(
    'GOOGLE_CLIENT_ID',
    'NEXT_PUBLIC_GOOGLE_CLIENT_ID',
  );

  if (!googleClientId) {
    sendRedirect(
      res,
      buildReturnUrl(origin, returnTo, {
        youtube_error: 'Google OAuth is not configured on this deployment.',
      }),
    );
    return;
  }

  if (!sessionId) {
    console.warn('[YouTube OAuth] Missing Clerk session handoff cookie');
    sendRedirect(
      res,
      buildReturnUrl(origin, returnTo, {
        youtube_error:
          'TubeFlow could not find the YouTube auth session cookie. Start YouTube connect again from the app.',
      }),
    );
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

  sendRedirect(res, authUrl.toString(), [
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
  ]);
};
