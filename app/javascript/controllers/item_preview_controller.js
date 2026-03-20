import { Controller } from "@hotwired/stimulus"

// Modal preview for products/services from cart line items.
// The controller lives on a common ancestor so line item buttons can dispatch to it.
// The actual modal element is a "modal" target within the ancestor.
// Previews are fetched as server-rendered HTML.
export default class extends Controller {
  static targets = ["modal", "title", "content"]

  connect() {
    document.addEventListener("keydown", this.boundKeydown = (e) => {
      if (e.key === "Escape" && this.hasModalTarget && !this.modalTarget.classList.contains("hidden")) {
        this.close()
      }
    })
  }

  disconnect() {
    document.removeEventListener("keydown", this.boundKeydown)
  }

  open(event) {
    // Read data attributes from the triggering element (not Stimulus params,
    // since the controller is on an ancestor, not the button's direct parent).
    const btn = event.currentTarget
    const type = btn.dataset.sellableType
    const id = btn.dataset.sellableId
    if (!type || !id) return

    this.modalTarget.classList.remove("hidden")
    this.loadItem(type, id)
  }

  close() {
    if (this.hasModalTarget) {
      this.modalTarget.classList.add("hidden")
    }
  }

  async loadItem(type, id) {
    const displayType = type.replace(/([a-z])([A-Z])/g, "$1 $2")
    this.titleTarget.textContent = `${displayType} Preview`
    this.contentTarget.innerHTML = `
      <div class="flex items-center justify-center h-75">
        <div class="text-center space-y-3">
          <svg class="mx-auto h-8 w-8 text-muted animate-spin" fill="none" viewBox="0 0 24 24"><circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"/><path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4z"/></svg>
          <p class="text-sm text-muted">Loading...</p>
        </div>
      </div>`

    const urls = { Product: `/products/${id}/preview`, Service: `/services/${id}/preview` }
    const url = urls[type]

    if (!url) {
      this.renderBasicPreview(type, id)
      return
    }

    try {
      const response = await fetch(url, { headers: { "Accept": "text/html" } })

      if (response.ok) {
        const html = await response.text()
        this.renderPreview(html, type, id)
      } else {
        this.renderBasicPreview(type, id)
      }
    } catch {
      this.renderBasicPreview(type, id)
    }
  }

  fullPath(type, id) {
    const paths = { Product: `/products/${id}`, Service: `/services/${id}`, GiftCertificate: `/admin/gift_certificates/${id}` }
    return paths[type] || null
  }

  renderLinkHtml(type, id) {
    const path = this.fullPath(type, id)
    if (!path) return ""

    const label = type === "GiftCertificate" ? "gift certificate" : type.toLowerCase()
    return `
      <div class="px-5 pb-5 border-t border-theme pt-3">
        <a href="${path}" target="_blank" rel="noopener"
           class="flex w-full items-center justify-center gap-2 rounded-lg border border-theme px-4 py-2 text-xs font-medium text-body hover:bg-(--color-border) transition">
          <svg class="h-3.5 w-3.5" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M10 6H6a2 2 0 00-2 2v10a2 2 0 002 2h10a2 2 0 002-2v-4M14 4h6m0 0v6m0-6L10 14"/></svg>
          Open full ${label} page
        </a>
      </div>`
  }

  renderPreview(html, type, id) {
    this.titleTarget.textContent = type.replace(/([a-z])([A-Z])/g, "$1 $2")
    this.contentTarget.innerHTML = `${html}${this.renderLinkHtml(type, id)}`
  }

  renderBasicPreview(type, id) {
    this.titleTarget.textContent = type.replace(/([a-z])([A-Z])/g, "$1 $2")

    this.contentTarget.innerHTML = `
      <div class="p-5 space-y-4">
        <p class="text-xs text-muted">Detailed preview unavailable for this item.</p>
      </div>
      ${this.renderLinkHtml(type, id)}`
  }
}
