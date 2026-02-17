import { Controller } from "@hotwired/stimulus"

// Split-pane product/service search modal.
// Left side: search results list with filter pills. Right side: live preview.
// Arrow keys to navigate, Enter to add to order, click to select/preview.
export default class extends Controller {
  static targets = ["input", "results", "preview", "filterBar"]
  static values = { orderId: Number }

  connect() {
    this.selectedIndex = -1
    this.searchResults = []
    this.debounceTimer = null
    this.previewCache = new Map()
    this.activeFilter = "all"

    document.addEventListener("keydown", this.boundKeydown = (e) => {
      if (e.key === "Escape" && !this.element.classList.contains("hidden")) {
        this.close()
      }
    })
  }

  disconnect() {
    document.removeEventListener("keydown", this.boundKeydown)
    if (this.debounceTimer) clearTimeout(this.debounceTimer)
  }

  setFilter(event) {
    this.activeFilter = event.currentTarget.dataset.filter
    this.updateFilterPills()
    this.triggerSearch()
  }

  updateFilterPills() {
    if (!this.hasFilterBarTarget) return
    this.filterBarTarget.querySelectorAll("button").forEach(btn => {
      const isActive = btn.dataset.filter === this.activeFilter
      btn.className = `rounded-full px-2.5 py-0.5 text-[11px] font-medium transition ${
        isActive ? "bg-accent text-white" : "text-muted hover:bg-[var(--color-border)]"
      }`
    })
  }

  search() {
    if (this.debounceTimer) clearTimeout(this.debounceTimer)
    this.debounceTimer = setTimeout(() => this.triggerSearch(), 150)
  }

  triggerSearch() {
    const query = this.inputTarget.value.trim()
    if (query.length < 1) {
      this.resultsTarget.innerHTML = '<div class="p-6 text-center text-sm text-muted">Type to search for products or services</div>'
      this.clearPreview()
      return
    }
    this.performSearch(query)
  }

  async performSearch(query) {
    try {
      let url = `/search.json?q=${encodeURIComponent(query)}&limit=20`
      if (this.activeFilter !== "all") {
        url += `&type=${encodeURIComponent(this.activeFilter)}`
      }
      const response = await fetch(url)
      const data = await response.json()
      this.searchResults = (data.results || []).filter(r => r.type === "Product" || r.type === "Service")
      this.selectedIndex = this.searchResults.length > 0 ? 0 : -1
      this.renderResults()
      if (this.selectedIndex >= 0) {
        this.loadPreview(this.searchResults[0])
      } else {
        this.clearPreview()
      }
    } catch (e) {
      this.resultsTarget.innerHTML = '<div class="p-6 text-center text-sm text-red-500">Search failed</div>'
    }
  }

  renderResults() {
    if (this.searchResults.length === 0) {
      const filterLabel = this.activeFilter === "all" ? "products or services" : this.activeFilter.toLowerCase() + "s"
      this.resultsTarget.innerHTML = `<div class="p-6 text-center text-sm text-muted">No ${filterLabel} found</div>`
      return
    }

    const html = this.searchResults.map((result, idx) => {
      const isProduct = result.type === "Product"
      const selected = idx === this.selectedIndex
      const bgClass = selected ? "bg-accent/10 border-l-2 border-l-accent" : "border-l-2 border-l-transparent"
      return `
        <button type="button"
                class="flex w-full items-center justify-between px-4 py-2.5 text-left hover:bg-[var(--color-border)] transition ${bgClass}"
                data-action="click->product-search#selectItem dblclick->product-search#addItem"
                data-index="${idx}"
                data-type="${result.type}"
                data-id="${result.record_id}">
          <div class="min-w-0 flex-1">
            <div class="flex items-center gap-2">
              <span class="text-sm font-medium text-body truncate">${this.escapeHtml(result.label)}</span>
              <span class="shrink-0 rounded-full px-1.5 py-0.5 text-[10px] font-medium ${isProduct ? 'bg-blue-100 text-blue-800' : 'bg-purple-100 text-purple-800'}">${result.type}</span>
            </div>
            ${result.sublabel ? `<span class="text-xs text-muted">${this.escapeHtml(result.sublabel)}</span>` : ""}
          </div>
          <svg class="h-4 w-4 shrink-0 text-muted opacity-50" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5l7 7-7 7"/></svg>
        </button>
      `
    }).join("")

    this.resultsTarget.innerHTML = html

    const selectedBtn = this.resultsTarget.children[this.selectedIndex]
    if (selectedBtn) selectedBtn.scrollIntoView({ block: "nearest" })
  }

  navigate(event) {
    const len = this.searchResults.length
    if (len === 0) return

    if (event.key === "ArrowDown") {
      event.preventDefault()
      this.selectedIndex = Math.min(this.selectedIndex + 1, len - 1)
      this.renderResults()
      this.loadPreview(this.searchResults[this.selectedIndex])
    } else if (event.key === "ArrowUp") {
      event.preventDefault()
      this.selectedIndex = Math.max(this.selectedIndex - 1, 0)
      this.renderResults()
      this.loadPreview(this.searchResults[this.selectedIndex])
    } else if (event.key === "Enter" && this.selectedIndex >= 0) {
      event.preventDefault()
      const result = this.searchResults[this.selectedIndex]
      if (result) this.addToOrder(result.type, result.record_id)
    }
  }

  selectItem(event) {
    const idx = parseInt(event.currentTarget.dataset.index, 10)
    this.selectedIndex = idx
    this.renderResults()
    const result = this.searchResults[idx]
    if (result) this.loadPreview(result)
  }

  addItem(event) {
    const type = event.currentTarget.dataset.type
    const id = event.currentTarget.dataset.id
    this.addToOrder(type, id)
  }

  async addToOrder(type, id) {
    const token = document.querySelector('meta[name="csrf-token"]')?.content
    const orderId = this.orderIdValue

    try {
      const response = await fetch(`/orders/${orderId}/order_lines`, {
        method: "POST",
        headers: {
          "Content-Type": "application/x-www-form-urlencoded",
          "X-CSRF-Token": token,
          "Accept": "text/vnd.turbo-stream.html"
        },
        body: `sellable_type=${type}&sellable_id=${id}&quantity=1`
      })

      if (response.ok) {
        const html = await response.text()
        Turbo.renderStreamMessage(html)
        this.close()
      }
    } catch (e) {
      console.error("Failed to add item:", e)
    }
  }

  async loadPreview(result) {
    if (!this.hasPreviewTarget) return

    const cacheKey = `${result.type}-${result.record_id}`

    if (this.previewCache.has(cacheKey)) {
      this.renderPreview(this.previewCache.get(cacheKey), result.type, result)
      return
    }

    this.previewTarget.innerHTML = `
      <div class="flex h-full items-center justify-center p-6">
        <div class="text-center text-sm text-muted">Loading...</div>
      </div>`

    try {
      const url = result.type === "Product" ? `/products/${result.record_id}` : `/services/${result.record_id}`
      const response = await fetch(url, { headers: { "Accept": "application/json" } })

      if (response.ok) {
        const data = await response.json()
        this.previewCache.set(cacheKey, data)
        this.renderPreview(data, result.type, result)
      } else {
        this.renderBasicPreview(result)
      }
    } catch {
      this.renderBasicPreview(result)
    }
  }

  renderPreview(data, type, result) {
    const isProduct = type === "Product"
    const stockHtml = isProduct ? `
      <div class="rounded-lg border border-theme bg-surface p-3">
        <span class="text-xs font-medium uppercase tracking-wider text-muted">Stock Level</span>
        <p class="mt-1 text-lg font-bold ${(data.stock_level || 0) <= 0 ? 'text-red-600' : (data.stock_level || 0) <= 5 ? 'text-yellow-600' : 'text-body'}">${data.stock_level ?? 'N/A'}</p>
      </div>` : ""

    const categoryHtml = data.category ? `
      <div class="flex items-center gap-2 text-xs">
        <span class="text-muted">Category:</span>
        <span class="rounded-full bg-gray-100 px-2 py-0.5 text-gray-700">${this.escapeHtml(data.category)}</span>
      </div>` : ""

    const supplierHtml = data.supplier ? `
      <div class="flex items-center gap-2 text-xs">
        <span class="text-muted">Supplier:</span>
        <span class="text-body">${this.escapeHtml(data.supplier)}</span>
      </div>` : ""

    const taxHtml = data.tax_code ? `
      <div class="flex items-center gap-2 text-xs">
        <span class="text-muted">Tax:</span>
        <span class="text-body">${this.escapeHtml(data.tax_code)}</span>
      </div>` : ""

    const descriptionHtml = (data.description || data.notes) ? `
      <div class="border-t border-theme pt-3">
        <span class="text-xs font-medium uppercase tracking-wider text-muted">Description</span>
        <p class="mt-1 text-xs text-muted leading-relaxed">${this.escapeHtml(data.description || data.notes || "")}</p>
      </div>` : ""

    this.previewTarget.innerHTML = `
      <div class="p-5 space-y-4">
        <div>
          <div class="flex items-start justify-between gap-2">
            <h3 class="text-base font-semibold text-body">${this.escapeHtml(data.name || "")}</h3>
            <span class="shrink-0 rounded-full px-2 py-0.5 text-[10px] font-medium ${isProduct ? 'bg-blue-100 text-blue-800' : 'bg-purple-100 text-purple-800'}">${type}</span>
          </div>
          <p class="mt-0.5 text-xs font-mono text-muted">${this.escapeHtml(data.code || "")}</p>
        </div>

        <div class="grid grid-cols-2 gap-3">
          <div class="rounded-lg border border-theme bg-surface p-3">
            <span class="text-xs font-medium uppercase tracking-wider text-muted">Price</span>
            <p class="mt-1 text-lg font-bold text-body">$${parseFloat(data.selling_price || data.price || 0).toFixed(2)}</p>
            ${data.cost_price ? `<p class="text-[10px] text-muted">Cost: $${parseFloat(data.cost_price).toFixed(2)}</p>` : ""}
          </div>
          ${stockHtml}
        </div>

        <div class="space-y-1.5">
          ${categoryHtml}
          ${supplierHtml}
          ${taxHtml}
        </div>

        ${descriptionHtml}

        <div class="border-t border-theme pt-3">
          <button type="button"
                  class="w-full rounded-lg bg-accent px-4 py-2 text-xs font-semibold text-white hover:bg-[var(--color-accent-hover)] transition"
                  data-action="click->product-search#addPreviewItem"
                  data-type="${type}"
                  data-id="${result.record_id}">
            Add to Order
          </button>
          <p class="mt-2 text-center text-[10px] text-muted">Or press Enter, or double-click the result</p>
        </div>
      </div>`
  }

  renderBasicPreview(result) {
    this.previewTarget.innerHTML = `
      <div class="p-5 space-y-4">
        <div>
          <h3 class="text-base font-semibold text-body">${this.escapeHtml(result.label)}</h3>
          ${result.sublabel ? `<p class="text-xs text-muted">${this.escapeHtml(result.sublabel)}</p>` : ""}
        </div>
        <p class="text-xs text-muted">Detailed preview unavailable for this item.</p>
        <button type="button"
                class="w-full rounded-lg bg-accent px-4 py-2 text-xs font-semibold text-white hover:bg-[var(--color-accent-hover)] transition"
                data-action="click->product-search#addPreviewItem"
                data-type="${result.type}"
                data-id="${result.record_id}">
          Add to Order
        </button>
      </div>`
  }

  addPreviewItem(event) {
    const type = event.currentTarget.dataset.type
    const id = event.currentTarget.dataset.id
    this.addToOrder(type, id)
  }

  clearPreview() {
    if (!this.hasPreviewTarget) return
    this.previewTarget.innerHTML = `
      <div class="flex h-full items-center justify-center p-6">
        <div class="text-center">
          <svg class="mx-auto h-10 w-10 text-muted opacity-30" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="1.5" d="M15 12a3 3 0 11-6 0 3 3 0 016 0z"/><path stroke-linecap="round" stroke-linejoin="round" stroke-width="1.5" d="M2.458 12C3.732 7.943 7.523 5 12 5c4.478 0 8.268 2.943 9.542 7-1.274 4.057-5.064 7-9.542 7-4.477 0-8.268-2.943-9.542-7z"/></svg>
          <p class="mt-2 text-xs text-muted">Select an item to preview</p>
        </div>
      </div>`
  }

  close() {
    this.element.classList.add("hidden")
    this.inputTarget.value = ""
    this.searchResults = []
    this.selectedIndex = -1
    this.activeFilter = "all"
    this.updateFilterPills()
    this.resultsTarget.innerHTML = '<div class="p-6 text-center text-sm text-muted">Type to search for products or services</div>'
    this.clearPreview()

    const codeInput = document.getElementById("code_lookup_input")
    if (codeInput) codeInput.focus()
  }

  escapeHtml(text) {
    const div = document.createElement("div")
    div.textContent = text
    return div.innerHTML
  }
}
