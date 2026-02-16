// Configure your import map in config/importmap.rb. Read more: https://github.com/rails/importmap-rails
import "@hotwired/turbo-rails"
import "controllers"
import LocalTime from "local-time"

LocalTime.start()
document.addEventListener("turbo:morph", () => LocalTime.run())

// Intercept Turbo navigations to filter pages and rewrite the URL with
// stored filter params BEFORE the request fires. This prevents the visible
// flash of the unfiltered page that would otherwise occur when clicking a
// sidebar link while filters are active.
document.addEventListener("turbo:before-visit", (event) => {
  const url = new URL(event.detail.url)

  // Only intercept bare navigations (no query params already set)
  if (url.search) return

  try {
    const pathMap = JSON.parse(localStorage.getItem("table_filter_paths") || "{}")
    const storageKey = pathMap[url.pathname]
    if (!storageKey) return

    const raw = localStorage.getItem(storageKey)
    if (!raw) return

    const stored = JSON.parse(raw)
    if (!stored || Object.keys(stored).length === 0) return

    for (const [key, value] of Object.entries(stored)) {
      url.searchParams.set(key, value)
    }

    event.preventDefault()
    Turbo.visit(url.toString(), { action: "replace" })
  } catch (_e) {
    // If anything goes wrong, let the original navigation proceed
  }
})

// Register service worker for PWA
if ("serviceWorker" in navigator) {
  window.addEventListener("load", () => {
    navigator.serviceWorker.register("/service-worker").catch(() => {})
  })
}
