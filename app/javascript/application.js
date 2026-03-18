// Configure your import map in config/importmap.rb. Read more: https://github.com/rails/importmap-rails
import "@hotwired/turbo-rails"
import "controllers"
import LocalTime from "local-time"

LocalTime.start()

Turbo.config.drive.progressBarDelay = 500

document.addEventListener("turbo:morph", () => LocalTime.run())

// Rewrite a bare URL with stored filter params if available.
// Returns true if params were appended, false otherwise.
function rewriteWithStoredFilters(url) {
  if (url.search) return false

  try {
    const pathMap = JSON.parse(localStorage.getItem("table_filter_paths") || "{}")
    const storageKey = pathMap[url.pathname]
    if (!storageKey) return false

    const raw = localStorage.getItem(storageKey)
    if (!raw) return false

    const stored = JSON.parse(raw)
    if (!stored || Object.keys(stored).length === 0) return false

    for (const [key, value] of Object.entries(stored)) {
      url.searchParams.set(key, value)
    }
    return true
  } catch (_e) {
    return false
  }
}

// Intercept Turbo navigations to filter pages and rewrite the URL with
// stored filter params BEFORE the request fires. This prevents the visible
// flash of the unfiltered page that would otherwise occur when clicking a
// sidebar link while filters are active.
document.addEventListener("turbo:before-visit", (event) => {
  const url = new URL(event.detail.url)
  if (!rewriteWithStoredFilters(url)) return

  event.preventDefault()
  Turbo.visit(url.toString(), { action: "replace" })
})

// Rewrite prefetch requests with stored filter params so the prefetched
// response is for the filtered URL, not the bare path.
document.addEventListener("turbo:before-fetch-request", (event) => {
  if (!event.detail.fetchOptions?.headers?.["X-Sec-Purpose"]?.includes("prefetch") &&
      !event.detail.fetchOptions?.headers?.["Purpose"]?.includes("prefetch") &&
      !event.detail.fetchOptions?.headers?.["Sec-Purpose"]?.includes("prefetch")) return

  const url = new URL(event.detail.url)
  if (rewriteWithStoredFilters(url)) {
    event.detail.url = url
  }
})

// Register service worker for PWA
if ("serviceWorker" in navigator) {
  window.addEventListener("load", () => {
    navigator.serviceWorker.register("/service-worker").catch(() => {})
  })
}
