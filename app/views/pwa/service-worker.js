const ASSET_CACHE_NAME = "ei-pos-assets-v4"
const PAGE_CACHE_NAME = "ei-pos-pages-v1"
const VITE_PATH_PATTERN = /^\/vite(?:-test)?\//
const OFFLINE_FALLBACK_PATH = "/offline"

self.addEventListener("install", () => {
  self.skipWaiting()
})

self.addEventListener("activate", (event) => {
  event.waitUntil(
    Promise.all([
      caches.keys().then((keys) =>
        Promise.all(keys.filter((key) => ![ASSET_CACHE_NAME, PAGE_CACHE_NAME].includes(key)).map((key) => caches.delete(key)))
      ),
      self.registration.navigationPreload?.enable()
    ]).then(() => self.clients.claim())
  )
})

self.addEventListener("fetch", (event) => {
  const request = event.request

  if (request.method !== "GET") return
  const url = new URL(request.url)
  if (url.origin !== self.location.origin) return

  if (request.mode === "navigate") {
    event.respondWith(networkFirstNavigation(request, event.preloadResponse))
    return
  }

  if (acceptsHtml(request) && url.pathname === OFFLINE_FALLBACK_PATH) {
    event.respondWith(networkFirstPage(request))
    return
  }

  if (VITE_PATH_PATTERN.test(url.pathname) || ["/icon.png", "/icon-192.png", "/icon.svg"].includes(url.pathname)) {
    event.respondWith(cacheFirstAsset(request))
  }
})

async function networkFirstNavigation(request, preloadResponsePromise) {
  try {
    const preloadResponse = await preloadResponsePromise
    const response = preloadResponse || await fetch(request)
    cacheOfflinePage(request, response)
    return response
  } catch (_error) {
    return await caches.match(request) ||
      await caches.match(OFFLINE_FALLBACK_PATH) ||
      offlineFallbackResponse()
  }
}

async function networkFirstPage(request) {
  try {
    const response = await fetch(request)
    cacheOfflinePage(request, response)
    return response
  } catch (_error) {
    return await caches.match(request) ||
      await caches.match(OFFLINE_FALLBACK_PATH) ||
      offlineFallbackResponse()
  }
}

function cacheOfflinePage(request, response) {
  if (!response?.ok || !acceptsHtml(request)) return
  if (new URL(request.url).pathname !== OFFLINE_FALLBACK_PATH) return

  const copy = response.clone()
  caches.open(PAGE_CACHE_NAME).then((cache) => cache.put(request, copy))
}

function cacheFirstAsset(request) {
  return caches.match(request).then((cachedResponse) => {
    if (cachedResponse) return cachedResponse

    return fetch(request).then((response) => {
      if (!response.ok) return response

      const copy = response.clone()
      caches.open(ASSET_CACHE_NAME).then((cache) => cache.put(request, copy))
      return response
    })
  })
}

function acceptsHtml(request) {
  return request.headers.get("accept")?.includes("text/html")
}

function offlineFallbackResponse() {
  return new Response("EI Point of Sale is offline and no cached lookup is available yet.", {
    status: 503,
    headers: { "Content-Type": "text/plain; charset=utf-8" }
  })
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
