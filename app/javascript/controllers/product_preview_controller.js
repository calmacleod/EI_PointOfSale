import { Controller } from "@hotwired/stimulus"

// Quick Look modal for product/service details.
// Triggered by pressing Space in the search results.
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
      const url = result.type === "Product" ? `/products/${result.record_id}` : `/services/${result.record_id}`
      const response = await fetch(url, { headers: { "Accept": "application/json" } })

      if (response.ok) {
        const data = await response.json()
        this.renderPreview(data, result.type)
      } else {
        this.renderBasicPreview(result)
      }
    } catch {
      this.renderBasicPreview(result)
    }
  }

  renderPreview(data, type) {
    this.contentTarget.innerHTML = `
      <div class="space-y-3">
        <div class="flex items-start justify-between">
          <div>
            <h3 class="text-lg font-semibold text-body">${this.escapeHtml(data.name || "")}</h3>
            <p class="text-xs font-mono text-muted">${this.escapeHtml(data.code || "")}</p>
          </div>
          <span class="rounded-full px-2 py-0.5 text-xs font-medium ${type === 'Product' ? 'bg-blue-100 text-blue-800' : 'bg-purple-100 text-purple-800'}">${type}</span>
        </div>
        <div class="flex gap-4 text-sm">
          <div><span class="text-muted">Price:</span> <span class="font-medium text-body">$${parseFloat(data.selling_price || data.price || 0).toFixed(2)}</span></div>
          ${type === "Product" ? `<div><span class="text-muted">Stock:</span> <span class="font-medium ${(data.stock_level || 0) <= 0 ? 'text-red-600' : 'text-body'}">${data.stock_level || 0}</span></div>` : ""}
        </div>
        ${data.description || data.notes ? `<p class="text-xs text-muted">${this.escapeHtml(data.description || data.notes || "")}</p>` : ""}
        <div class="pt-2 text-center">
          <button type="button" class="text-xs text-muted hover:text-body" data-action="click->product-preview#close">Press Space or ESC to close</button>
        </div>
      </div>
    `
  }

  renderBasicPreview(result) {
    this.contentTarget.innerHTML = `
      <div class="space-y-3">
        <h3 class="text-lg font-semibold text-body">${this.escapeHtml(result.label)}</h3>
        ${result.sublabel ? `<p class="text-sm text-muted">${this.escapeHtml(result.sublabel)}</p>` : ""}
        <p class="text-xs text-muted">Full details unavailable in preview mode.</p>
        <div class="pt-2 text-center">
          <button type="button" class="text-xs text-muted hover:text-body" data-action="click->product-preview#close">Press Space or ESC to close</button>
        </div>
      </div>
    `
  }

  close() {
    this.element.classList.add("hidden")
    this.contentTarget.innerHTML = ""
  }

  escapeHtml(text) {
    const div = document.createElement("div")
    div.textContent = text
    return div.innerHTML
  }
}
