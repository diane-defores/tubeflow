const {
  getEnv,
  getRequestOrigin,
  isSecureOrigin,
  parseCookies,
  serializeCookie,
  buildReturnUrl,
  sendRedirect,
} = require('../_youtube');

async function exchangeCodeForTokens({
  code,
  clientId,
  clientSecret,
  redirectUri,
}) {
  const response = await fetch('https://oauth2.googleapis.com/token', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/x-www-form-urlencoded',
    },
    body: new URLSearchParams({
      code,
      client_id: clientId,
      client_secret: clientSecret,
      redirect_uri: redirectUri,
      grant_type: 'authorization_code',
    }),
  });

  if (!response.ok) {
    const errorText = await response.text();
    throw new Error(`Google token exchange failed: ${errorText}`);
  }

  return response.json();
}

async function mintConvexJwt(sessionId, clerkSecretKey) {
  const response = await fetch(
    `https://api.clerk.com/v1/sessions/${encodeURIComponent(sessionId)}/tokens/convex`,
    {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${clerkSecretKey}`,
        'Content-Type': 'application/json',
      },
      body: '{}',
    },
  );

  if (!response.ok) {
    const errorText = await response.text();
    throw new Error(`Clerk token mint failed: ${errorText}`);
  }

  const payload = await response.json();
  if (!payload || !payload.jwt) {
    throw new Error('Clerk token mint returned no JWT.');
  }

  return payload.jwt;
}

async function saveYoutubeTokens(convexUrl, convexJwt, tokens) {
  const response = await fetch(`${convexUrl.replace(/\/+$/, '')}/api/mutation`, {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${convexJwt}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      path: 'youtube:saveYoutubeTokens',
      args: {
        accessToken: tokens.access_token,
        refreshToken: tokens.refresh_token,
        expiresIn: tokens.expires_in,
      },
      format: 'json',
    }),
  });

  if (!response.ok) {
    const errorText = await response.text();
    throw new Error(`Convex mutation failed: ${errorText}`);
  }
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
  const code = requestUrl.searchParams.get('code');
  const state = requestUrl.searchParams.get('state');
  const oauthError = requestUrl.searchParams.get('error');

  const cookies = parseCookies(req.headers.cookie);
  const storedState = cookies.youtube_oauth_state;
  const returnTo = cookies.youtube_oauth_return_to;
  const sessionId = cookies.clerk_session_id;

  const googleClientId = getEnv(
    'GOOGLE_CLIENT_ID',
    'NEXT_PUBLIC_GOOGLE_CLIENT_ID',
  );
  const googleClientSecret = getEnv('GOOGLE_CLIENT_SECRET');
  const clerkSecretKey = getEnv('CLERK_SECRET_KEY');
  const convexUrl = getEnv('CONVEX_URL', 'NEXT_PUBLIC_CONVEX_URL');

  const cleanupCookies = [
    serializeCookie('youtube_oauth_state', '', {
      path: '/',
      httpOnly: true,
      sameSite: 'Lax',
      secure,
      maxAge: 0,
    }),
    serializeCookie('youtube_oauth_return_to', '', {
      path: '/',
      httpOnly: true,
      sameSite: 'Lax',
      secure,
      maxAge: 0,
    }),
    serializeCookie('clerk_session_id', '', {
      path: '/',
      sameSite: 'Lax',
      secure,
      maxAge: 0,
    }),
  ];

  function redirectWithError(message) {
    sendRedirect(
      res,
      buildReturnUrl(origin, returnTo, {
        youtube_error: message,
      }),
      cleanupCookies,
    );
  }

  if (oauthError) {
    redirectWithError(`Google OAuth failed: ${oauthError}`);
    return;
  }

  if (!code || !state) {
    redirectWithError('Google did not return a valid YouTube authorisation code.');
    return;
  }

  if (!storedState || storedState !== state) {
    redirectWithError('TubeFlow could not verify the YouTube OAuth state.');
    return;
  }

  if (!sessionId) {
    redirectWithError('TubeFlow lost the Clerk session needed to finish YouTube setup.');
    return;
  }

  if (!googleClientId || !googleClientSecret) {
    redirectWithError('Google OAuth credentials are missing on this deployment.');
    return;
  }

  if (!clerkSecretKey) {
    redirectWithError('Clerk server credentials are missing on this deployment.');
    return;
  }

  if (!convexUrl) {
    redirectWithError('Convex is not configured on this deployment.');
    return;
  }

  try {
    const redirectUri = new URL('/api/auth/youtube/callback', origin).toString();
    const tokens = await exchangeCodeForTokens({
      code,
      clientId: googleClientId,
      clientSecret: googleClientSecret,
      redirectUri,
    });

    const convexJwt = await mintConvexJwt(sessionId, clerkSecretKey);
    await saveYoutubeTokens(convexUrl, convexJwt, tokens);

    sendRedirect(
      res,
      buildReturnUrl(origin, returnTo, {
        youtube_connected: 'true',
      }),
      cleanupCookies,
    );
  } catch (error) {
    redirectWithError(
      error instanceof Error
        ? error.message
        : 'TubeFlow could not complete the YouTube callback.',
    );
  }
};
