// Bump CACHE_VERSION whenever bundle.js meaningfully changes — this
// forces SW activation which clears the old cache and re-precaches assets.
const CACHE_VERSION = "ei-pos-v2"
const PRECACHE_URLS = [
  "/offline",
  "/offline/bundle.js",
  "/offline/sync.js",
  "/offline/sync-lib.js",
  "/icon.png",
  "/icon-192.png",
  "/icon.svg"
]

self.addEventListener("install", (event) => {
  event.waitUntil(
    caches.open(CACHE_VERSION).then((cache) => cache.addAll(PRECACHE_URLS))
  )
  self.skipWaiting()
})

self.addEventListener("activate", (event) => {
  event.waitUntil(
    caches.keys().then((keys) =>
      Promise.all(keys.filter((k) => k !== CACHE_VERSION).map((k) => caches.delete(k)))
    )
  )
  self.clients.claim()
})

self.addEventListener("fetch", (event) => {
  const { request } = event

  if (request.method !== "GET") return

  if (request.mode === "navigate") {
    const url = new URL(request.url)
    if (url.pathname === "/offline") {
      event.respondWith(cacheFirst(request))
      return
    }
    event.respondWith(networkFirstWithOfflineFallback(request))
    return
  }

  const url = new URL(request.url)
  const isAsset = /\.(css|js|woff2?|ttf|png|jpg|jpeg|gif|svg|ico|webp)$/i.test(url.pathname)

  if (isAsset) {
    event.respondWith(staleWhileRevalidate(request))
  }
})

async function networkFirstWithOfflineFallback(request) {
  try {
    const response = await fetch(request)
    if (response.ok) {
      const cache = await caches.open(CACHE_VERSION)
      cache.put(request, response.clone())
    }
    return response
  } catch {
    const cached = await caches.match(request)
    if (cached) return cached
    return caches.match("/offline")
  }
}

async function cacheFirst(request) {
  const cached = await caches.match(request)
  if (cached) return cached
  try {
    const response = await fetch(request)
    if (response.ok) {
      const cache = await caches.open(CACHE_VERSION)
      cache.put(request, response.clone())
    }
    return response
  } catch {
    return new Response("Offline page not cached yet", { status: 503 })
  }
}

async function staleWhileRevalidate(request) {
  const cache = await caches.open(CACHE_VERSION)
  const cached = await cache.match(request)

  const fetchPromise = fetch(request).then((response) => {
    if (response.ok) cache.put(request, response.clone())
    return response
  }).catch(() => cached)

  return cached || fetchPromise
}

// ── Web Push Notifications ──────────────────────────────────────────

self.addEventListener("push", (event) => {
  const data = event.data?.json() || {}
  event.waitUntil(
    self.registration.showNotification(data.title || "EI POS", {
      body: data.body,
      icon: "/icon-192.png",
      badge: "/icon-192.png",
      data: { url: data.url }
    })
  )
})

self.addEventListener("notificationclick", (event) => {
  event.notification.close()
  const url = event.notification.data?.url || "/"
  event.waitUntil(
    clients.matchAll({ type: "window" }).then((list) => {
      for (const client of list) {
        if (new URL(client.url).pathname === url && "focus" in client) {
          return client.focus()
        }
      }
      return clients.openWindow(url)
    })
  )
})
