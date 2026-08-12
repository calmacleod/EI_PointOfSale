import { createInertiaApp, router } from "@inertiajs/svelte"
import { browserOnline } from "../lib/connection.js"
import { warmOfflineCatalog } from "../lib/offline-catalog.js"
import Layout from "../layouts/AppLayout.svelte"
import "./application.css"

const warmOfflineRouteChunk = () => import("../pages/components/OfflinePage.svelte")
const OFFLINE_PAGE_REFRESH_INTERVAL_MS = 60 * 60 * 1000
const OFFLINE_PAGE_FETCHED_AT_KEY = "ei-pos-offline-page-fetched-at"
let serviceWorkerRegistrationPromise = null

createInertiaApp({
  pages: "../pages",
  layout: () => Layout,
  defaults: {
    form: {
      forceIndicesArrayFormatInFormData: false,
      withAllErrors: true,
    },
    visitOptions: () => ({ queryStringArrayFormat: "brackets" }),
    future: {
      useScriptElementForInitialPage: true,
      useDataInertiaHeadAttribute: true,
      useDialogForErrorModal: true,
      preserveEqualProps: true,
    },
  },
})

if ("serviceWorker" in navigator) {
  ensureServiceWorkerRegistration().catch(() => {})
  window.addEventListener("load", () => {
    ensureServiceWorkerRegistration().catch(() => {})
  })
}

window.addEventListener("load", () => {
  scheduleIdleWork(() => warmOfflineSupport(authenticatedPage()))
  if (!browserOnline()) redirectToOfflinePage()
})

router.on("navigate", (event) => {
  scheduleIdleWork(() => warmOfflineSupport(authenticatedProps(event.detail.page.props)))
})

router.on("httpException", (event) => {
  if (!shouldHandleOfflineInertiaFailure()) return

  event.preventDefault()
  redirectToOfflinePage()
  return false
})

router.on("networkError", (event) => {
  if (authenticationPath()) return

  event.preventDefault()
  redirectToOfflinePage()
  return false
})

window.addEventListener("offline", redirectToOfflinePage)

function scheduleIdleWork(callback) {
  if ("requestIdleCallback" in window) {
    window.requestIdleCallback(callback, { timeout: 2500 })
  } else {
    window.setTimeout(callback, 1000)
  }
}

async function warmOfflineSupport(authenticated) {
  try {
    if ("serviceWorker" in navigator) {
      await ensureServiceWorkerRegistration()
      await warmApplicationAssets()
      await warmOfflineRouteChunk()
    }

    if (!authenticated) return

    warmOfflineCatalog()
    warmOfflinePage()
  } catch (_error) {
    // Offline preparation is opportunistic and must never interrupt the live app.
  }
}

function warmOfflinePage() {
  if (!shouldRefreshOfflinePage()) return

  writeStorageValue(OFFLINE_PAGE_FETCHED_AT_KEY, new Date().toISOString())
  fetch("/offline", { credentials: "same-origin", headers: { Accept: "text/html" } }).catch(() => {})
}

function shouldRefreshOfflinePage() {
  const fetchedAt = Date.parse(readStorageValue(OFFLINE_PAGE_FETCHED_AT_KEY))
  return !Number.isFinite(fetchedAt) || Date.now() - fetchedAt >= OFFLINE_PAGE_REFRESH_INTERVAL_MS
}

async function ensureServiceWorkerRegistration() {
  serviceWorkerRegistrationPromise ||= navigator.serviceWorker
    .register("/service-worker")
    .then(() => navigator.serviceWorker.ready)

  return serviceWorkerRegistrationPromise
}

async function warmApplicationAssets() {
  const viteUrls = new Set(
    performance
      .getEntriesByType("resource")
      .map((entry) => new URL(entry.name, window.location.origin))
      .filter((url) => url.origin === window.location.origin && /^\/vite(?:-test)?\//.test(url.pathname))
      .map((url) => url.pathname),
  )

  await Promise.all(Array.from(viteUrls).map((url) => fetch(url, { credentials: "same-origin" }).catch(() => null)))
}

function redirectToOfflinePage() {
  if (window.location.pathname === "/offline") return
  if (window.location.pathname.startsWith("/session")) return
  if (window.location.pathname.startsWith("/passwords")) return

  window.location.assign("/offline")
}

function shouldHandleOfflineInertiaFailure() {
  return !browserOnline() || window.location.pathname === "/offline"
}

function authenticationPath() {
  return window.location.pathname.startsWith("/session") || window.location.pathname.startsWith("/passwords")
}

function authenticatedPage() {
  const pageScript = document.querySelector('script[data-page="app"]')
  if (!pageScript?.textContent) return false

  try {
    return authenticatedProps(JSON.parse(pageScript.textContent).props)
  } catch (_error) {
    return false
  }
}

function authenticatedProps(props) {
  return Boolean(props?.auth?.authenticated)
}

function readStorageValue(key) {
  try {
    return window.localStorage.getItem(key)
  } catch (_error) {
    return null
  }
}

function writeStorageValue(key, value) {
  try {
    window.localStorage.setItem(key, value)
  } catch (_error) {
    // Page refresh throttling is best-effort.
  }
}
