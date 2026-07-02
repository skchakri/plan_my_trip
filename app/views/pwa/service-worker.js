// Wanderply — service worker
// Strategy: stale-while-revalidate for app shell + trip pages so once a
// page has been visited it stays available offline. Asset files are
// cached on first request and refreshed in the background.

const VERSION = "v8";
const RUNTIME_CACHE = `pmt-runtime-${VERSION}`;
const ASSET_CACHE   = `pmt-assets-${VERSION}`;
const PAGE_CACHE    = `pmt-pages-${VERSION}`;
const MAP_CACHE     = `pmt-maps-${VERSION}`;
const IMAGE_CACHE   = `pmt-images-${VERSION}`; // flag + brand-logo CDNs (immutable)

const APP_SHELL = [
  "/",
  "/icon.svg",
  "/icon.png"
];

self.addEventListener("install", (event) => {
  event.waitUntil(
    caches.open(PAGE_CACHE).then((cache) => cache.addAll(APP_SHELL).catch(() => null))
      .then(() => self.skipWaiting())
  );
});

self.addEventListener("activate", (event) => {
  event.waitUntil(
    caches.keys().then((keys) =>
      Promise.all(
        keys
          .filter((k) => ![RUNTIME_CACHE, ASSET_CACHE, PAGE_CACHE, MAP_CACHE, IMAGE_CACHE].includes(k))
          .map((k) => caches.delete(k))
      )
    ).then(() => self.clients.claim())
  );
});

function isMapTile(url) {
  return url.host === "tile.openstreetmap.org"
      || url.host.endsWith(".tile.openstreetmap.org");
}

// Quiz flag + brand-logo images live on external CDNs and are immutable, so
// cache-first keeps them available offline once fetched.
function isQuizImage(url) {
  return url.host === "flagcdn.com" || url.host === "cdn.simpleicons.org";
}

function isAsset(url) {
  return /\.(?:js|css|svg|png|jpg|jpeg|gif|webp|ico|woff2?)$/i.test(url.pathname)
      || url.pathname.startsWith("/assets/")
      || url.host === "fonts.googleapis.com"
      || url.host === "fonts.gstatic.com";
}

function isPage(url) {
  return url.origin === self.location.origin
      && (url.pathname === "/"
          || url.pathname.startsWith("/trips")
          || url.pathname.startsWith("/quizzes")
          || url.pathname.startsWith("/users/edit"));
}

self.addEventListener("fetch", (event) => {
  const req = event.request;
  if (req.method !== "GET") return; // mutations always hit the network

  const url = new URL(req.url);

  // Never cache auth flows or sign-out
  if (url.pathname.startsWith("/users/sign_in") ||
      url.pathname.startsWith("/users/sign_out") ||
      url.pathname.startsWith("/users/sign_up") ||
      url.pathname.startsWith("/users/password") ||
      url.pathname.startsWith("/invitations")) {
    return;
  }

  if (isMapTile(url)) {
    // Map tiles are immutable — once fetched, always serve from cache.
    event.respondWith(cacheFirst(req, MAP_CACHE));
    return;
  }

  if (isQuizImage(url)) {
    // Checked before isAsset (flag URLs end in .png) so logos + flags share
    // one immutable image cache.
    event.respondWith(cacheFirst(req, IMAGE_CACHE));
    return;
  }

  if (isAsset(url)) {
    event.respondWith(staleWhileRevalidate(req, ASSET_CACHE));
    return;
  }

  if (isPage(url)) {
    event.respondWith(networkFallingBackToCache(req, PAGE_CACHE));
    return;
  }
});

// Pre-cache a list of URLs (currently OSM map tiles) when the page asks
// the SW to "Save maps offline". Replies on the MessageChannel port with
// progress + a final done/error message.
self.addEventListener("message", (event) => {
  const data = event.data || {};
  const port = event.ports && event.ports[0];
  if (data.type !== "PRECACHE" || !Array.isArray(data.urls)) return;

  event.waitUntil((async () => {
    try {
      const cache = await caches.open(MAP_CACHE);
      const urls = data.urls;
      const total = urls.length;
      let cached = 0;
      // Throttle to avoid hammering the OSM tile server. 6-wide pool is
      // well within the OSM Foundation's "no bulk download" guidance for
      // a personal trip's worth of tiles (~70 tiles for a 4-day trip).
      const concurrency = 6;
      let idx = 0;
      const workers = Array.from({ length: concurrency }, async () => {
        while (idx < urls.length) {
          const myIdx = idx++;
          const url = urls[myIdx];
          try {
            const existing = await cache.match(url);
            if (existing) {
              cached++;
            } else {
              const res = await fetch(url, { mode: "no-cors" });
              await cache.put(url, res);
              cached++;
            }
          } catch (e) {
            // skip — partial success is fine
          }
          if (port) port.postMessage({ type: "PRECACHE_PROGRESS", cached, total });
        }
      });
      await Promise.all(workers);
      if (port) port.postMessage({ type: "PRECACHE_DONE", cached, total });
    } catch (err) {
      if (port) port.postMessage({ type: "PRECACHE_ERROR", error: String(err) });
    }
  })());
});

// "Save quizzes for offline": precache every deck page + all flag/logo images
// so all decks play with no connection. Pages go to PAGE_CACHE (same-origin,
// credentialed), images to IMAGE_CACHE (cross-origin, opaque).
self.addEventListener("message", (event) => {
  const data = event.data || {};
  const port = event.ports && event.ports[0];
  if (data.type !== "PRECACHE_QUIZ") return;

  event.waitUntil((async () => {
    try {
      const pages = Array.isArray(data.pages) ? data.pages : [];
      const images = Array.isArray(data.images) ? data.images : [];
      const total = pages.length + images.length;
      let cached = 0;

      let succeeded = 0;

      const fill = async (urls, cacheName, mode) => {
        const cache = await caches.open(cacheName);
        let idx = 0;
        const workers = Array.from({ length: 8 }, async () => {
          while (idx < urls.length) {
            const u = urls[idx++];
            try {
              if (await cache.match(u)) {
                succeeded++;
              } else {
                const res = await fetchWithRetry(u, mode ? { mode } : undefined, 2);
                // Never cache an error response (404/500) — only OK or opaque
                // (no-cors CDN) responses, so a transient blip doesn't poison
                // the offline cache with a broken entry.
                if (res && (res.ok || res.type === "opaque")) {
                  await cache.put(u, res);
                  succeeded++;
                }
              }
            } catch (e) { /* counted as attempted; not succeeded */ }
            cached++;
            if (port) port.postMessage({ type: "PRECACHE_PROGRESS", cached, total, succeeded });
          }
        });
        await Promise.all(workers);
      };

      await fill(pages, PAGE_CACHE);            // same-origin deck pages (cookies sent)
      await fill(images, IMAGE_CACHE, "no-cors"); // flag + logo CDNs (opaque)
      // Report succeeded vs total so the UI can be honest about partial saves.
      if (port) port.postMessage({ type: "PRECACHE_DONE", cached, total, succeeded });
    } catch (err) {
      if (port) port.postMessage({ type: "PRECACHE_ERROR", error: String(err) });
    }
  })());
});

// Fetch with bounded retries + backoff, so one flaky CDN response doesn't drop
// an asset from the offline precache. Returns the last response (caller decides
// whether to cache it); throws only if every attempt threw.
async function fetchWithRetry(url, opts, retries) {
  let lastErr;
  for (let attempt = 0; attempt <= retries; attempt++) {
    try {
      const res = await fetch(url, opts);
      if (res && (res.ok || res.type === "opaque")) return res;
      lastErr = null;
    } catch (e) {
      lastErr = e;
    }
    if (attempt < retries) await new Promise((r) => setTimeout(r, 300 * (attempt + 1)));
  }
  if (lastErr) throw lastErr;
  return undefined;
}

async function cacheFirst(req, cacheName) {
  const cache = await caches.open(cacheName);
  const cached = await cache.match(req);
  if (cached) return cached;
  try {
    const res = await fetch(req, { mode: "no-cors" });
    if (res) cache.put(req, res.clone()).catch(() => {});
    return res;
  } catch (e) {
    // Offline + uncached — let the broken-image render rather than
    // synthesizing a fake PNG. The page itself is still usable.
    return new Response("", { status: 504, headers: { "Content-Type": "image/png" } });
  }
}

async function staleWhileRevalidate(req, cacheName) {
  const cache = await caches.open(cacheName);
  const cached = await cache.match(req);
  const network = fetch(req).then((res) => {
    if (res && res.ok) cache.put(req, res.clone());
    return res;
  }).catch(() => cached);
  return cached || network;
}

// Pages: try the network first so we get fresh data when online; fall
// back to the last good cached HTML if the user is offline.
async function networkFallingBackToCache(req, cacheName) {
  const cache = await caches.open(cacheName);
  try {
    const fresh = await fetch(req);
    if (fresh && fresh.ok && fresh.type === "basic") {
      cache.put(req, fresh.clone()).catch(() => {});
    }
    return fresh;
  } catch (e) {
    const cached = await cache.match(req);
    if (cached) return cached;
    // Last-ditch: serve the cached app shell so the user sees something.
    const fallback = await cache.match("/");
    if (fallback) return fallback;
    return new Response("You're offline and this page hasn't been visited yet.", {
      status: 503,
      headers: { "Content-Type": "text/plain" }
    });
  }
}
