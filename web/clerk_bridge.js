(function () {
  let loadPromise = null;
  const CLERK_JS_SCRIPT_ID = 'tubeflow-clerk-js';
  const CLERK_UI_SCRIPT_ID = 'tubeflow-clerk-ui';

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

  function getActiveSession(clerk) {
    if (clerk.session) {
      return clerk.session;
    }

    const client = clerk.client;
    if (!client) {
      return null;
    }

    if (client.lastActiveSessionId && Array.isArray(client.sessions)) {
      const active = client.sessions.find(
        (session) => session.id === client.lastActiveSessionId,
      );
      if (active) {
        return active;
      }
    }

    if (Array.isArray(client.signedInSessions) && client.signedInSessions.length > 0) {
      return client.signedInSessions[0];
    }

    if (Array.isArray(client.sessions) && client.sessions.length > 0) {
      return client.sessions[0];
    }

    return null;
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

  window.tubeFlowClerkBridge = {
    async init(publishableKey) {
      await ensureLoaded(publishableKey);
      return true;
    },

    async isSignedIn(publishableKey) {
      const clerk = await ensureLoaded(publishableKey);
      return !!clerk.isSignedIn;
    },

    async getUserJson(publishableKey) {
      const clerk = await ensureLoaded(publishableKey);
      return serializeUser(clerk.user);
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

        await clerk.load({
          ui: window.__internal_ClerkUICtor
            ? { ClerkUI: window.__internal_ClerkUICtor }
            : undefined,
        });

        session = getActiveSession(clerk);
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
        signInForceRedirectUrl: redirectUrl,
        signUpForceRedirectUrl: redirectUrl,
      });
    },

    async signOut(publishableKey) {
      const clerk = await ensureLoaded(publishableKey);
      await clerk.signOut();
      return true;
    },
  };
})();
