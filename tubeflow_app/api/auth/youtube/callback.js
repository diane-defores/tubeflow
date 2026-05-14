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

async function runConvexMutation(convexUrl, convexJwt, path, args) {
  const response = await fetch(`${convexUrl.replace(/\/+$/, '')}/api/mutation`, {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${convexJwt}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      path,
      args,
      format: 'json',
    }),
  });

  if (!response.ok) {
    const errorText = await response.text();
    throw new Error(`Convex mutation failed: ${errorText}`);
  }

  const payload = await response.json();
  if (payload?.status === 'error') {
    throw new Error(
      `Convex mutation ${path} failed: ${payload.errorMessage || JSON.stringify(payload)}`,
    );
  }

  return payload;
}

function decodeJwtPayload(jwt) {
  const [, payload] = jwt.split('.');
  if (!payload) return {};
  const normalized = payload.replace(/-/g, '+').replace(/_/g, '/');
  const padded = normalized.padEnd(
    normalized.length + ((4 - (normalized.length % 4)) % 4),
    '=',
  );
  return JSON.parse(Buffer.from(padded, 'base64').toString('utf8'));
}

async function ensureConvexUser(convexUrl, convexJwt) {
  const payload = decodeJwtPayload(convexJwt);
  const emailAddress = payload.email;

  if (!emailAddress) {
    throw new Error('Firebase ID token returned no email address.');
  }

  await runConvexMutation(convexUrl, convexJwt, 'users:ensureUser', {
    email: emailAddress,
    name: payload.name || undefined,
    avatarUrl: payload.picture || undefined,
  });
}

async function saveYoutubeTokens(convexUrl, convexJwt, tokens) {
  await runConvexMutation(convexUrl, convexJwt, 'youtube:saveYoutubeTokens', {
    accessToken: tokens.access_token,
    refreshToken: tokens.refresh_token,
    expiresIn: tokens.expires_in,
  });
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
  const firebaseIdToken = cookies.tubeflow_youtube_firebase_id_token;

  const googleClientId = getEnv('GOOGLE_CLIENT_ID');
  const googleClientSecret = getEnv('GOOGLE_CLIENT_SECRET');
  const convexUrl = getEnv('CONVEX_URL');

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
    serializeCookie('tubeflow_youtube_firebase_id_token', '', {
      path: '/',
      httpOnly: true,
      sameSite: 'Lax',
      secure,
      maxAge: 0,
    }),
  ];

  function sendCallbackRedirect(extraParams) {
    sendRedirect(
      res,
      buildReturnUrl(origin, returnTo, extraParams),
      cleanupCookies,
    );
  }

  function redirectWithError(message) {
    sendCallbackRedirect({ youtube_error: message });
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

  if (!firebaseIdToken) {
    redirectWithError(
      'TubeFlow lost the Firebase auth handoff before callback. Start YouTube connect again from the app.',
    );
    return;
  }

  if (!googleClientId || !googleClientSecret) {
    redirectWithError('Google OAuth credentials are missing on this deployment.');
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

    await ensureConvexUser(convexUrl, firebaseIdToken);
    await saveYoutubeTokens(convexUrl, firebaseIdToken, tokens);

    sendCallbackRedirect({ youtube_connected: 'true' });
  } catch (error) {
    console.error('[YouTube OAuth Callback] Failed to complete callback', {
      message: error instanceof Error ? error.message : String(error),
    });
    redirectWithError(
      error instanceof Error
        ? error.message
        : 'TubeFlow could not complete the YouTube callback.',
    );
  }
};
