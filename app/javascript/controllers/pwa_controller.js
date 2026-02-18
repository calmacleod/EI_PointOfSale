import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    this.standalone = window.matchMedia("(display-mode: standalone)").matches ||
                      window.navigator.standalone === true

    if (this.standalone) {
      this.boundClickHandler = this.interceptExternalLinks.bind(this)
      this.element.addEventListener("click", this.boundClickHandler, true)

      // Add class to main content for PWA-specific styling (sidebar doesn't need it)
      const mainContent = document.querySelector("main")
      if (mainContent) mainContent.classList.add("pwa-standalone")
    }
  }

  disconnect() {
    if (this.boundClickHandler) {
      this.element.removeEventListener("click", this.boundClickHandler, true)
    }
  }

  interceptExternalLinks(event) {
    const link = event.target.closest("a[href]")
    if (!link) return

    const href = link.getAttribute("href")
    if (!href || href.startsWith("#") || href.startsWith("javascript:")) return

    try {
      const url = new URL(href, window.location.origin)
      if (url.origin !== window.location.origin) {
        event.preventDefault()
        event.stopPropagation()
        window.open(url.href, "_blank", "noopener,noreferrer")
      }
    } catch {
      // Malformed URL — let the browser handle it
    }
  }
}
