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

async function fetchClerkSession(sessionId, clerkSecretKey) {
  const response = await fetch(
    `https://api.clerk.com/v1/sessions/${encodeURIComponent(sessionId)}`,
    {
      headers: {
        Authorization: `Bearer ${clerkSecretKey}`,
      },
    },
  );

  if (!response.ok) {
    const errorText = await response.text();
    throw new Error(`Clerk session lookup failed: ${errorText}`);
  }

  return response.json();
}

async function fetchClerkUser(userId, clerkSecretKey) {
  const response = await fetch(
    `https://api.clerk.com/v1/users/${encodeURIComponent(userId)}`,
    {
      headers: {
        Authorization: `Bearer ${clerkSecretKey}`,
      },
    },
  );

  if (!response.ok) {
    const errorText = await response.text();
    throw new Error(`Clerk user lookup failed: ${errorText}`);
  }

  return response.json();
}

async function ensureConvexUser(convexUrl, convexJwt, clerkSecretKey, sessionId) {
  const session = await fetchClerkSession(sessionId, clerkSecretKey);
  const userId = session?.user_id;
  if (!userId) {
    throw new Error('Clerk session lookup returned no user_id.');
  }

  const user = await fetchClerkUser(userId, clerkSecretKey);
  const primaryEmailId = user?.primary_email_address_id;
  const emailAddress =
    user?.email_addresses?.find((entry) => entry?.id === primaryEmailId)
      ?.email_address ||
    user?.email_addresses?.[0]?.email_address;

  if (!emailAddress) {
    throw new Error('Clerk user lookup returned no email address.');
  }

  await runConvexMutation(convexUrl, convexJwt, 'users:ensureUser', {
    email: emailAddress,
    name:
      [user?.first_name, user?.last_name]
        .filter(Boolean)
        .join(' ')
        .trim() || undefined,
    avatarUrl: user?.image_url || undefined,
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
  const sessionId =
    cookies.tubeflow_youtube_clerk_session_id || cookies.clerk_session_id;

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
    serializeCookie('tubeflow_youtube_clerk_session_id', '', {
      path: '/',
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
    await ensureConvexUser(convexUrl, convexJwt, clerkSecretKey, sessionId);
    await saveYoutubeTokens(convexUrl, convexJwt, tokens);

    sendCallbackRedirect({ youtube_connected: 'true' });
  } catch (error) {
    redirectWithError(
      error instanceof Error
        ? error.message
        : 'TubeFlow could not complete the YouTube callback.',
    );
  }
};
