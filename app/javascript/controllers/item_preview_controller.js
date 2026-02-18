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
    this.titleTarget.textContent = `${type} Preview`
    this.contentTarget.innerHTML = '<div class="p-6 text-center text-sm text-muted">Loading...</div>'

    try {
      const url = type === "Product" ? `/products/${id}/preview` : `/services/${id}/preview`
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

  renderPreview(html, type, id) {
    const fullPath = type === "Product" ? `/products/${id}` : `/services/${id}`

    this.titleTarget.textContent = type

    this.contentTarget.innerHTML = `
      ${html}
      <div class="px-5 pb-5 border-t border-theme pt-3">
        <a href="${fullPath}" target="_blank" rel="noopener"
           class="flex w-full items-center justify-center gap-2 rounded-lg border border-theme px-4 py-2 text-xs font-medium text-body hover:bg-[var(--color-border)] transition">
          <svg class="h-3.5 w-3.5" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M10 6H6a2 2 0 00-2 2v10a2 2 0 002 2h10a2 2 0 002-2v-4M14 4h6m0 0v6m0-6L10 14"/></svg>
          Open full ${type.toLowerCase()} page
        </a>
      </div>`
  }

  renderBasicPreview(type, id) {
    const fullPath = type === "Product" ? `/products/${id}` : `/services/${id}`

    this.titleTarget.textContent = type

    this.contentTarget.innerHTML = `
      <div class="p-5 space-y-4">
        <p class="text-xs text-muted">Detailed preview unavailable for this item.</p>
        <div class="border-t border-theme pt-3">
          <a href="${fullPath}" target="_blank" rel="noopener"
             class="flex w-full items-center justify-center gap-2 rounded-lg border border-theme px-4 py-2 text-xs font-medium text-body hover:bg-[var(--color-border)] transition">
            <svg class="h-3.5 w-3.5" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M10 6H6a2 2 0 00-2 2v10a2 2 0 002 2h10a2 2 0 002-2v-4M14 4h6m0 0v6m0-6L10 14"/></svg>
            Open full ${type.toLowerCase()} page
          </a>
        </div>
      </div>`
  }
}
