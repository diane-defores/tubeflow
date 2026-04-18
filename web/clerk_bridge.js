(function () {
  let loadPromise = null;

  function deriveFrontendApi(publishableKey) {
    const encoded = publishableKey.split('_')[2];
    return atob(encoded).slice(0, -1);
  }

  function loadScript(src) {
    return new Promise((resolve, reject) => {
      const existing = document.querySelector(`script[src="${src}"]`);
      if (existing) {
        existing.addEventListener('load', () => resolve(), { once: true });
        existing.addEventListener(
          'error',
          () => reject(new Error(`Failed to load ${src}`)),
          { once: true },
        );
        return;
      }

      const script = document.createElement('script');
      script.src = src;
      script.async = true;
      script.crossOrigin = 'anonymous';
      script.onload = () => resolve();
      script.onerror = () => reject(new Error(`Failed to load ${src}`));
      document.head.appendChild(script);
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
        const src = `https://${frontendApi}/npm/@clerk/clerk-js@6/dist/clerk.browser.js`;

        if (!window.Clerk) {
          await loadScript(src);
        }

        await window.Clerk.load();
        return window.Clerk;
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
      if (!clerk.session) return '';

      const options = { skipCache: true };
      if (template) {
        options.template = template;
      }

      const token = await clerk.session.getToken(options);
      return token || '';
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
