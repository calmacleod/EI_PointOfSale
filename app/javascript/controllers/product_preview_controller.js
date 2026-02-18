import { Controller } from "@hotwired/stimulus"

// Quick Look modal for product/service details.
// Triggered by pressing Space in the search results.
// Previews are fetched as server-rendered HTML.
export default class extends Controller {
  static targets = ["content"]

  connect() {
    document.addEventListener("keydown", this.boundKeydown = (e) => {
      if (!this.element.classList.contains("hidden")) {
        if (e.key === "Escape" || e.key === " ") {
          e.preventDefault()
          this.close()
        }
      }
    })
  }

  disconnect() {
    document.removeEventListener("keydown", this.boundKeydown)
  }

  async loadPreview(result) {
    this.element.classList.remove("hidden")
    this.contentTarget.innerHTML = '<div class="text-center text-sm text-muted py-8">Loading...</div>'

    try {
      const url = result.type === "Product" ? `/products/${result.record_id}/preview` : `/services/${result.record_id}/preview`
      const response = await fetch(url, { headers: { "Accept": "text/html" } })

      if (response.ok) {
        const html = await response.text()
        this.contentTarget.innerHTML = this.wrapPreview(html)
      } else {
        this.renderBasicPreview(result)
      }
    } catch {
      this.renderBasicPreview(result)
    }
  }

  wrapPreview(html) {
    // Wrap the server-rendered preview in a simplified quick-look container
    return `
      <div class="p-4">
        ${html}
        <div class="pt-4 text-center">
          <button type="button" class="text-xs text-muted hover:text-body" data-action="click->product-preview#close">Press Space or ESC to close</button>
        </div>
      </div>`
  }

  renderBasicPreview(result) {
    this.contentTarget.innerHTML = `
      <div class="p-4 space-y-3">
        <h3 class="text-lg font-semibold text-body">${result.label}</h3>
        ${result.sublabel ? `<p class="text-sm text-muted">${result.sublabel}</p>` : ""}
        <p class="text-xs text-muted">Full details unavailable in preview mode.</p>
        <div class="pt-4 text-center">
          <button type="button" class="text-xs text-muted hover:text-body" data-action="click->product-preview#close">Press Space or ESC to close</button>
        </div>
      </div>`
  }

  close() {
    this.element.classList.add("hidden")
    this.contentTarget.innerHTML = ""
  }
}
