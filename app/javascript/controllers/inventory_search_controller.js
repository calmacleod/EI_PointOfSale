import { Controller } from "@hotwired/stimulus"

// Split-pane product search modal for the inventory restock page.
// Reuses the existing /search/product_results endpoint for results,
// and /products/:id/preview for the preview pane.
// On selection, dispatches "inventory-search:select" with product data.
export default class extends Controller {
  static targets = ["input", "results", "preview"]
  static values = { lookupUrl: String }

  connect() {
    this.selectedIndex = -1
    this.searchResults = []
    this.debounceTimer = null
    this.previewKey = null

    this.boundKeydown = (e) => {
      if (e.key === "Escape" && !this.element.classList.contains("hidden")) {
        this.close()
      }
    }
    document.addEventListener("keydown", this.boundKeydown)
  }

  disconnect() {
    document.removeEventListener("keydown", this.boundKeydown)
    if (this.debounceTimer) clearTimeout(this.debounceTimer)
  }

  search() {
    if (this.debounceTimer) clearTimeout(this.debounceTimer)
    this.debounceTimer = setTimeout(() => this.triggerSearch(), 150)
  }

  triggerSearch() {
    const query = this.inputTarget.value.trim()
    if (query.length < 1) {
      this.showPlaceholder()
      return
    }
    this.performSearch(query)
  }

  showPlaceholder() {
    this.resultsTarget.innerHTML = '<div class="p-6 text-center text-sm text-muted">Type to search for products</div>'
    this.clearPreview()
    this.searchResults = []
    this.selectedIndex = -1
  }

  async performSearch(query) {
    try {
      const url = `/search/product_results?q=${encodeURIComponent(query)}&limit=20&type=Product`
      const response = await fetch(url, { headers: { "Accept": "text/html" } })

      if (response.ok) {
        const html = await response.text()
        this.resultsTarget.innerHTML = html
        this.refreshSearchResultsFromDom()
        this.selectedIndex = this.searchResults.length > 0 ? 0 : -1
        this.updateSelectionDisplay()

        if (this.selectedIndex >= 0) {
          const first = this.searchResults[0]
          this.loadPreview(first.id)
        } else {
          this.clearPreview()
        }
      }
    } catch {
      this.resultsTarget.innerHTML = '<div class="p-6 text-center text-sm text-red-500">Search failed</div>'
    }
  }

  refreshSearchResultsFromDom() {
    this.searchResults = []
    const buttons = this.resultsTarget.querySelectorAll("[data-type][data-id]")
    buttons.forEach((btn, idx) => {
      // Rebind actions for inventory context
      btn.dataset.action = "click->inventory-search#selectItem dblclick->inventory-search#addItem"
      btn.dataset.index = idx
      this.searchResults.push({ id: parseInt(btn.dataset.id), index: idx })
    })
  }

  updateSelectionDisplay() {
    const buttons = this.resultsTarget.querySelectorAll("[data-type][data-id]")
    buttons.forEach((btn, idx) => {
      if (idx === this.selectedIndex) {
        btn.classList.remove("border-l-transparent")
        btn.classList.add("bg-accent/20", "border-l-4", "border-l-accent")
        const container = this.resultsTarget
        const btnTop = btn.offsetTop
        const btnBottom = btnTop + btn.offsetHeight
        if (btnTop < container.scrollTop) {
          container.scrollTop = btnTop
        } else if (btnBottom > container.scrollTop + container.clientHeight) {
          container.scrollTop = btnBottom - container.clientHeight
        }
      } else {
        btn.classList.remove("bg-accent/20", "border-l-accent")
        btn.classList.add("border-l-4", "border-l-transparent")
      }
    })
  }

  navigate(event) {
    const len = this.searchResults.length
    if (len === 0) return

    if (event.key === "ArrowDown") {
      event.preventDefault()
      this.selectedIndex = Math.min(this.selectedIndex + 1, len - 1)
      this.updateSelectionDisplay()
      this.loadPreview(this.searchResults[this.selectedIndex].id)
    } else if (event.key === "ArrowUp") {
      event.preventDefault()
      this.selectedIndex = Math.max(this.selectedIndex - 1, 0)
      this.updateSelectionDisplay()
      this.loadPreview(this.searchResults[this.selectedIndex].id)
    } else if (event.key === "Enter" && this.selectedIndex >= 0) {
      event.preventDefault()
      this.addProductById(this.searchResults[this.selectedIndex].id)
    }
  }

  selectItem(event) {
    const idx = parseInt(event.currentTarget.dataset.index, 10)
    this.selectedIndex = idx
    this.updateSelectionDisplay()
    this.loadPreview(this.searchResults[idx].id)
  }

  addItem(event) {
    const id = parseInt(event.currentTarget.dataset.id, 10)
    this.addProductById(id)
  }

  async addProductById(id) {
    // Lookup the product to get full data, then dispatch event to bulk-restock
    try {
      const url = `${this.lookupUrlValue}?code=&id=${id}`
      // Use the lookup endpoint — but we need to pass the id. Let's use the
      // preview data we may already have, or just fetch the lookup by iterating.
      // Actually, we can get the data from the preview fetch or do a direct lookup.
      const response = await fetch(`${this.lookupUrlValue}?product_id=${id}`, {
        headers: { "Accept": "application/json" }
      })
      const data = await response.json()

      if (data.found) {
        this.element.dispatchEvent(new CustomEvent("inventory-search:select", {
          bubbles: true,
          detail: {
            id: data.id,
            code: data.code,
            name: data.name,
            supplier: data.supplier,
            stockLevel: data.stock_level
          }
        }))
        this.close()
      }
    } catch {
      // Fallback: close modal anyway
      this.close()
    }
  }

  async loadPreview(id) {
    if (!this.hasPreviewTarget) return
    const key = `Product-${id}`
    if (key === this.previewKey) return
    this.previewKey = key

    try {
      const response = await fetch(`/products/${id}/preview`, { headers: { "Accept": "text/html" } })
      if (response.ok) {
        const html = await response.text()
        const wrapped = `${html}
          <div class="px-5 pb-5 border-t border-theme pt-3">
            <button type="button"
                    class="w-full rounded-lg bg-accent px-4 py-2 text-xs font-semibold text-white hover:bg-(--color-accent-hover) transition"
                    data-action="click->inventory-search#addPreviewItem"
                    data-id="${id}">
              Add to Restock
            </button>
            <p class="mt-2 text-center text-[10px] text-muted">Or press Enter, or double-click the result</p>
          </div>`
        await this.swapPreview(wrapped)
      }
    } catch {
      // Ignore preview errors
    }
  }

  addPreviewItem(event) {
    const id = parseInt(event.currentTarget.dataset.id, 10)
    this.addProductById(id)
  }

  async swapPreview(html) {
    const el = this.previewTarget
    await el.animate(
      [{ opacity: 1, transform: "translateY(0)" }, { opacity: 0, transform: "translateY(-12px)" }],
      { duration: 100, easing: "ease-in", fill: "forwards" }
    ).finished
    el.scrollTop = 0
    el.innerHTML = html
    await el.animate(
      [{ opacity: 0, transform: "translateY(12px)" }, { opacity: 1, transform: "translateY(0)" }],
      { duration: 150, easing: "ease-out", fill: "forwards" }
    ).finished
    el.style.opacity = ""
    el.style.transform = ""
  }

  clearPreview() {
    if (!this.hasPreviewTarget) return
    this.previewTarget.innerHTML = `
      <div class="flex h-full items-center justify-center p-6">
        <div class="text-center">
          <svg class="mx-auto h-10 w-10 text-muted opacity-30" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="1.5" d="M15 12a3 3 0 11-6 0 3 3 0 016 0z"/><path stroke-linecap="round" stroke-linejoin="round" stroke-width="1.5" d="M2.458 12C3.732 7.943 7.523 5 12 5c4.478 0 8.268 2.943 9.542 7-1.274 4.057-5.064 7-9.542 7-4.477 0-8.268-2.943-9.542-7z"/></svg>
          <p class="mt-2 text-xs text-muted">Select a product to preview</p>
        </div>
      </div>`
  }

  close() {
    this.element.classList.add("hidden")
    this.inputTarget.value = ""
    this.searchResults = []
    this.selectedIndex = -1
    this.previewKey = null
    this.showPlaceholder()
  }
}
