import { Controller } from "@hotwired/stimulus"

// Modal preview for products/services from cart line items.
// The controller lives on a common ancestor so line item buttons can dispatch to it.
// The actual modal element is a "modal" target within the ancestor.
export default class extends Controller {
  static targets = ["modal", "title", "content"]

  connect() {
    this.cache = new Map()
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
    const cacheKey = `${type}-${id}`

    if (this.cache.has(cacheKey)) {
      this.renderPreview(this.cache.get(cacheKey), type, id)
      return
    }

    this.titleTarget.textContent = `${type} Preview`
    this.contentTarget.innerHTML = '<div class="p-6 text-center text-sm text-muted">Loading...</div>'

    try {
      const url = type === "Product" ? `/products/${id}` : `/services/${id}`
      const response = await fetch(url, { headers: { Accept: "application/json" } })

      if (response.ok) {
        const data = await response.json()
        this.cache.set(cacheKey, data)
        this.renderPreview(data, type, id)
      } else {
        this.contentTarget.innerHTML = '<div class="p-6 text-center text-sm text-red-500">Failed to load item details.</div>'
      }
    } catch {
      this.contentTarget.innerHTML = '<div class="p-6 text-center text-sm text-red-500">Failed to load item details.</div>'
    }
  }

  renderPreview(data, type, id) {
    const isProduct = type === "Product"
    const fullPath = isProduct ? `/products/${id}` : `/services/${id}`

    this.titleTarget.textContent = data.name || type

    const stockHtml = isProduct
      ? `<div class="rounded-lg border border-theme bg-surface-alt p-3">
           <span class="text-[10px] font-semibold uppercase tracking-wider text-muted">Stock</span>
           <p class="mt-0.5 text-lg font-bold ${(data.stock_level || 0) <= 0 ? "text-red-600" : (data.stock_level || 0) <= 5 ? "text-yellow-600" : "text-body"}">${data.stock_level ?? "N/A"}</p>
         </div>`
      : ""

    const categoryHtml = data.category
      ? `<div class="flex items-center justify-between text-xs">
           <span class="text-muted">Category</span>
           <span class="rounded-full bg-gray-100 px-2 py-0.5 text-gray-700">${this.esc(data.category)}</span>
         </div>`
      : ""

    const supplierHtml = data.supplier
      ? `<div class="flex items-center justify-between text-xs">
           <span class="text-muted">Supplier</span>
           <span class="text-body">${this.esc(data.supplier)}</span>
         </div>`
      : ""

    const taxHtml = data.tax_code
      ? `<div class="flex items-center justify-between text-xs">
           <span class="text-muted">Tax Code</span>
           <span class="text-body">${this.esc(data.tax_code)}</span>
         </div>`
      : ""

    const descHtml = (data.description || data.notes)
      ? `<div class="border-t border-theme pt-3">
           <span class="text-[10px] font-semibold uppercase tracking-wider text-muted">Description</span>
           <p class="mt-1 text-xs text-muted leading-relaxed">${this.esc(data.description || data.notes)}</p>
         </div>`
      : ""

    this.contentTarget.innerHTML = `
      <div class="p-5 space-y-4">
        <div>
          <div class="flex items-start justify-between gap-2">
            <div>
              <p class="text-xs font-mono text-muted">${this.esc(data.code || "")}</p>
            </div>
            <span class="shrink-0 rounded-full px-2 py-0.5 text-[10px] font-medium ${isProduct ? "bg-blue-100 text-blue-800" : "bg-purple-100 text-purple-800"}">${type}</span>
          </div>
        </div>

        <div class="grid grid-cols-2 gap-3">
          <div class="rounded-lg border border-theme bg-surface-alt p-3">
            <span class="text-[10px] font-semibold uppercase tracking-wider text-muted">Price</span>
            <p class="mt-0.5 text-lg font-bold text-body">$${parseFloat(data.selling_price || data.price || 0).toFixed(2)}</p>
            ${data.cost_price ? `<p class="text-[10px] text-muted">Cost: $${parseFloat(data.cost_price).toFixed(2)}</p>` : ""}
          </div>
          ${stockHtml}
        </div>

        <div class="space-y-2">
          ${categoryHtml}
          ${supplierHtml}
          ${taxHtml}
        </div>

        ${descHtml}

        <div class="border-t border-theme pt-3">
          <a href="${fullPath}" target="_blank" rel="noopener"
             class="flex w-full items-center justify-center gap-2 rounded-lg border border-theme px-4 py-2 text-xs font-medium text-body hover:bg-[var(--color-border)] transition">
            <svg class="h-3.5 w-3.5" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M10 6H6a2 2 0 00-2 2v10a2 2 0 002 2h10a2 2 0 002-2v-4M14 4h6m0 0v6m0-6L10 14"/></svg>
            Open full ${type.toLowerCase()} page
          </a>
        </div>
      </div>`
  }

  esc(text) {
    const div = document.createElement("div")
    div.textContent = text
    return div.innerHTML
  }
}
