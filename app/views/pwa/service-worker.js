// Plan My Trip — service worker
// Strategy: stale-while-revalidate for app shell + trip pages so once a
// page has been visited it stays available offline. Asset files are
// cached on first request and refreshed in the background.

const VERSION = "v3";
const RUNTIME_CACHE = `pmt-runtime-${VERSION}`;
const ASSET_CACHE   = `pmt-assets-${VERSION}`;
const PAGE_CACHE    = `pmt-pages-${VERSION}`;

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
          .filter((k) => ![RUNTIME_CACHE, ASSET_CACHE, PAGE_CACHE].includes(k))
          .map((k) => caches.delete(k))
      )
    ).then(() => self.clients.claim())
  );
});

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

  if (isAsset(url)) {
    event.respondWith(staleWhileRevalidate(req, ASSET_CACHE));
    return;
  }

  if (isPage(url)) {
    event.respondWith(networkFallingBackToCache(req, PAGE_CACHE));
    return;
  }
});

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
