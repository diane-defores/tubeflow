(function () {
  let loadPromise = null;
  const CLERK_JS_SCRIPT_ID = 'tubeflow-clerk-js';
  const CLERK_UI_SCRIPT_ID = 'tubeflow-clerk-ui';
  const DEBUG_LOG_KEY = 'tubeflow_clerk_bridge_debug';

  function debug(message, data) {
    try {
      const entries = JSON.parse(window.localStorage.getItem(DEBUG_LOG_KEY) || '[]');
      entries.push({
        timestamp: new Date().toISOString(),
        message,
        data: data || null,
      });
      window.localStorage.setItem(
        DEBUG_LOG_KEY,
        JSON.stringify(entries.slice(-80)),
      );
    } catch (_) {
      // Debug logging must never break auth.
    }
  }

  function deriveFrontendApi(publishableKey) {
    const encoded = publishableKey.split('_')[2];
    return atob(encoded).slice(0, -1);
  }

  function loadScript(src, options) {
    const { id, attributes } = options || {};
    return new Promise((resolve, reject) => {
      const existing =
        (id ? document.getElementById(id) : null) ||
        document.querySelector(`script[src="${src}"]`);
      if (existing) {
        if (existing.dataset.loaded === 'true') {
          resolve();
          return;
        }
        existing.addEventListener('load', () => resolve(), { once: true });
        existing.addEventListener(
          'error',
          () => reject(new Error(`Failed to load ${src}`)),
          { once: true },
        );
        return;
      }

      const script = document.createElement('script');
      if (id) {
        script.id = id;
      }
      script.src = src;
      script.defer = true;
      script.crossOrigin = 'anonymous';
      script.type = 'text/javascript';
      if (attributes) {
        Object.entries(attributes).forEach(([key, value]) => {
          if (value) {
            script.setAttribute(key, value);
          }
        });
      }
      script.onload = () => {
        script.dataset.loaded = 'true';
        resolve();
      };
      script.onerror = () => reject(new Error(`Failed to load ${src}`));
      document.head.appendChild(script);
    });
  }

  function waitForClerk(timeoutMs) {
    return new Promise((resolve, reject) => {
      const deadline = Date.now() + timeoutMs;

      function poll() {
        if (window.Clerk) {
          resolve(window.Clerk);
          return;
        }

        if (Date.now() >= deadline) {
          reject(new Error('ClerkJS loaded but window.Clerk is still undefined'));
          return;
        }

        window.setTimeout(poll, 25);
      }

      poll();
    });
  }

  async function ensureLoaded(publishableKey) {
    if (!publishableKey) {
      throw new Error('Missing Clerk publishable key');
    }

    if (window.Clerk && window.Clerk.loaded) {
      return window.Clerk;
    }

    if (!loadPromise) {
      loadPromise = (async () => {
        const frontendApi = deriveFrontendApi(publishableKey);
        const uiSrc = `https://${frontendApi}/npm/@clerk/ui@1/dist/ui.browser.js`;
        const clerkSrc = `https://${frontendApi}/npm/@clerk/clerk-js@6/dist/clerk.browser.js`;

        window.__clerk_publishable_key = publishableKey;

        if (!window.Clerk) {
          await loadScript(uiSrc, { id: CLERK_UI_SCRIPT_ID });
          await loadScript(clerkSrc, {
            id: CLERK_JS_SCRIPT_ID,
            attributes: {
              'data-clerk-publishable-key': publishableKey,
            },
          });
        }

        const clerk = await waitForClerk(5000);
        if (!clerk.loaded) {
          await clerk.load({
            ui: window.__internal_ClerkUICtor
              ? { ClerkUI: window.__internal_ClerkUICtor }
              : undefined,
          });
        }
        return clerk;
      })();
    }

    return loadPromise;
  }

  function serializeUser(user) {
    if (!user) return '';

    const primaryEmail =
      user.primaryEmailAddress?.emailAddress ||
      user.emailAddresses?.[0]?.emailAddress ||
      '';

    const displayName = `${user.firstName || ''} ${user.lastName || ''}`.trim();

    return JSON.stringify({
      id: user.id || '',
      email: primaryEmail,
      displayName,
      imageUrl: user.imageUrl || '',
    });
  }

  function sessionTimestamp(session) {
    const candidate =
      session?.lastActiveAt ||
      session?.updatedAt ||
      session?.createdAt ||
      null;

    if (!candidate) return 0;

    if (candidate instanceof Date) {
      return candidate.getTime();
    }

    const parsed = new Date(candidate).getTime();
    return Number.isNaN(parsed) ? 0 : parsed;
  }

  function isUsableSession(session) {
    if (!session || !session.id) {
      return false;
    }

    return session.status === 'active' || session.status === 'pending';
  }

  function getActiveSession(clerk, options) {
    const excludeIds = new Set(options?.excludeIds || []);
    const client = clerk.client;
    const candidates = new Map();

    function add(session, rank) {
      if (!isUsableSession(session) || excludeIds.has(session.id)) {
        return;
      }

      const existing = candidates.get(session.id);
      const candidate = {
        session,
        rank,
        timestamp: sessionTimestamp(session),
      };

      if (
        !existing ||
        candidate.rank < existing.rank ||
        (candidate.rank === existing.rank &&
          candidate.timestamp > existing.timestamp)
      ) {
        candidates.set(session.id, candidate);
      }
    }

    if (Array.isArray(client?.activeSessions)) {
      client.activeSessions.forEach((session) => add(session, 0));
    }

    if (Array.isArray(client?.signedInSessions)) {
      client.signedInSessions.forEach((session) => add(session, 1));
    }

    if (Array.isArray(client?.sessions)) {
      client.sessions.forEach((session) => add(session, 2));
    }

    add(clerk.session, 3);

    for (const preferredId of [client?.lastActiveSessionId, clerk.session?.id]) {
      if (!preferredId) {
        continue;
      }
      const preferred = candidates.get(preferredId);
      if (preferred) {
        return preferred.session;
      }
    }

    return [...candidates.values()]
      .sort((left, right) => {
        if (left.rank !== right.rank) {
          return left.rank - right.rank;
        }
        return right.timestamp - left.timestamp;
      })
      .map((entry) => entry.session)[0] || null;
  }

  function isMissingSessionError(error) {
    return (
      error &&
      (error.status === 404 ||
        error.code === 'resource_not_found' ||
        (Array.isArray(error.errors) &&
          error.errors.some((entry) => entry && entry.code === 'resource_not_found')))
    );
  }

  function clearClerkStorage() {
    const storages = [window.localStorage, window.sessionStorage];
    for (const storage of storages) {
      if (!storage) continue;
      const keys = [];
      for (let i = 0; i < storage.length; i += 1) {
        const key = storage.key(i);
        if (!key) continue;
        const normalized = key.toLowerCase();
        if (
          normalized.startsWith('__clerk') ||
          normalized.startsWith('clerk') ||
          normalized.includes('clerk')
        ) {
          keys.push(key);
        }
      }
      keys.forEach((key) => storage.removeItem(key));
    }
  }

  function writeYoutubeSessionCookie(sessionId) {
    if (!sessionId) {
      return false;
    }

    const parts = [
      `tubeflow_youtube_clerk_session_id=${encodeURIComponent(sessionId)}`,
      'Path=/',
      'Max-Age=600',
      'SameSite=Lax',
    ];

    if (window.location.protocol === 'https:') {
      parts.push('Secure');
    }

    document.cookie = parts.join('; ');
    return true;
  }

  window.tubeFlowClerkBridge = {
    async init(publishableKey) {
      await ensureLoaded(publishableKey);
      return true;
    },

    async isSignedIn(publishableKey) {
      const clerk = await ensureLoaded(publishableKey);
      return !!getActiveSession(clerk);
    },

    async getUserJson(publishableKey) {
      const clerk = await ensureLoaded(publishableKey);
      const session = getActiveSession(clerk);
      return serializeUser(session?.user || clerk.user);
    },

    async getToken(publishableKey, template) {
      const clerk = await ensureLoaded(publishableKey);
      const options = { skipCache: true };
      if (template) {
        options.template = template;
      }

      let session = getActiveSession(clerk);
      if (!session) return '';

      try {
        const token = await session.getToken(options);
        return token || '';
      } catch (error) {
        if (!isMissingSessionError(error)) {
          throw error;
        }

        session.clearCache?.();
        clerk.client?.clearCache?.();

        await clerk.load({
          ui: window.__internal_ClerkUICtor
            ? { ClerkUI: window.__internal_ClerkUICtor }
            : undefined,
        });

        session = getActiveSession(clerk, {
          excludeIds: session?.id ? [session.id] : [],
        });
        if (!session) {
          return '';
        }

        const token = await session.getToken(options);
        return token || '';
      }
    },

    async buildSignInUrl(publishableKey, redirectUrl) {
      const clerk = await ensureLoaded(publishableKey);
      return clerk.buildSignInUrl({
        redirectUrl,
        signInForceRedirectUrl: redirectUrl,
        signUpForceRedirectUrl: redirectUrl,
        signInFallbackRedirectUrl: redirectUrl,
        signUpFallbackRedirectUrl: redirectUrl,
      });
    },

    async openSignIn(publishableKey, redirectUrl) {
      const url = await this.buildSignInUrl(publishableKey, redirectUrl);
      if (!url) {
        throw new Error('Clerk did not return a sign-in URL.');
      }
      window.location.assign(url);
      return true;
    },

    async startGoogleSignIn(publishableKey, redirectUrl, redirectUrlComplete) {
      const clerk = await ensureLoaded(publishableKey);
      const signIn = clerk.signIn || clerk.client?.signIn;
      debug('startGoogleSignIn', {
        redirectUrl,
        redirectUrlComplete,
        hasAuthenticateWithRedirect: !!signIn?.authenticateWithRedirect,
        hasOpenSignIn: !!clerk.openSignIn,
        sessionId: clerk.session?.id || null,
      });
      if (signIn?.authenticateWithRedirect) {
        await signIn.authenticateWithRedirect({
          strategy: 'oauth_google',
          redirectCallbackUrl: redirectUrl,
          redirectUrl: redirectUrlComplete,
          redirectUrlComplete,
        });
        return true;
      }

      if (clerk.openSignIn) {
        clerk.openSignIn({
          oauthFlow: 'redirect',
          forceRedirectUrl: redirectUrlComplete,
          fallbackRedirectUrl: redirectUrlComplete,
          signUpForceRedirectUrl: redirectUrlComplete,
          signUpFallbackRedirectUrl: redirectUrlComplete,
        });
        return true;
      }

      throw new Error('Clerk JS does not expose a supported Google sign-in flow.');
    },

    async handleOAuthRedirect(publishableKey, redirectUrlComplete) {
      const clerk = await ensureLoaded(publishableKey);
      debug('handleOAuthRedirect:start', {
        href: window.location.href,
        redirectUrlComplete,
      });
      await clerk.handleRedirectCallback({
        signInForceRedirectUrl: redirectUrlComplete,
        signUpForceRedirectUrl: redirectUrlComplete,
        signInFallbackRedirectUrl: redirectUrlComplete,
        signUpFallbackRedirectUrl: redirectUrlComplete,
      });
      debug('handleOAuthRedirect:complete', {
        href: window.location.href,
        sessionId: clerk.session?.id || null,
        signedIn: !!getActiveSession(clerk),
      });
      return true;
    },

    async prepareSessionCookie(publishableKey) {
      const clerk = await ensureLoaded(publishableKey);
      const session = getActiveSession(clerk);
      if (!session || !session.id) {
        return false;
      }

      return writeYoutubeSessionCookie(session.id);
    },

    async prepareSessionCookieForSessionId(_publishableKey, sessionId) {
      return writeYoutubeSessionCookie(sessionId);
    },

    async signOut(publishableKey) {
      const clerk = await ensureLoaded(publishableKey);
      try {
        await clerk.signOut();
      } finally {
        clerk.session?.clearCache?.();
        clerk.client?.clearCache?.();
        clearClerkStorage();
      }
      return true;
    },

    async resetState(publishableKey) {
      const clerk = await ensureLoaded(publishableKey);
      try {
        await clerk.signOut();
      } catch (_) {
        // Ignore sign-out failures; we still want to clear local Clerk state.
      }
      clerk.session?.clearCache?.();
      clerk.client?.clearCache?.();
      clearClerkStorage();
      return true;
    },

    async getDebugLog() {
      return window.localStorage.getItem(DEBUG_LOG_KEY) || '';
    },
  };
})();
