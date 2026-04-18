(function () {
  let loadPromise = null;
  const CONVEX_SCRIPT_ID = 'tubeflow-convex-js';
  const CONVEX_BUNDLE_SRC =
    'https://unpkg.com/convex@1.29.3/dist/browser.bundle.js';

  function loadScript(src, id) {
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
      script.id = id;
      script.src = src;
      script.defer = true;
      script.crossOrigin = 'anonymous';
      script.type = 'text/javascript';
      script.onload = () => {
        script.dataset.loaded = 'true';
        resolve();
      };
      script.onerror = () => reject(new Error(`Failed to load ${src}`));
      document.head.appendChild(script);
    });
  }

  async function ensureLoaded() {
    if (window.convex && window.convex.ConvexHttpClient) {
      return window.convex;
    }

    if (!loadPromise) {
      loadPromise = (async () => {
        await loadScript(CONVEX_BUNDLE_SRC, CONVEX_SCRIPT_ID);
        if (!window.convex || !window.convex.ConvexHttpClient) {
          throw new Error('Convex browser bundle loaded but ConvexHttpClient is unavailable');
        }
        return window.convex;
      })();
    }

    return loadPromise;
  }

  function parseArgs(argsJson) {
    if (!argsJson) {
      return {};
    }
    const parsed = JSON.parse(argsJson);
    return parsed && typeof parsed === 'object' ? parsed : {};
  }

  async function createClient(convexUrl, authToken) {
    const convexLib = await ensureLoaded();
    const client = new convexLib.ConvexHttpClient(convexUrl);
    if (authToken) {
      await client.setAuth(authToken);
    }
    return client;
  }

  async function run(method, convexUrl, authToken, path, argsJson) {
    if (!convexUrl) {
      throw new Error('Missing Convex URL');
    }
    if (!path) {
      throw new Error('Missing Convex function path');
    }

    const client = await createClient(convexUrl, authToken);
    const args = parseArgs(argsJson);
    const result = await client[method](path, args);
    return JSON.stringify(result ?? null);
  }

  window.tubeFlowConvexBridge = {
    query(convexUrl, authToken, path, argsJson) {
      return run('query', convexUrl, authToken, path, argsJson);
    },

    mutate(convexUrl, authToken, path, argsJson) {
      return run('mutation', convexUrl, authToken, path, argsJson);
    },

    action(convexUrl, authToken, path, argsJson) {
      return run('action', convexUrl, authToken, path, argsJson);
    },
  };
})();
