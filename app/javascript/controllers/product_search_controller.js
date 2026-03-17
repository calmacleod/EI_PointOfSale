import { Controller } from "@hotwired/stimulus"

// Split-pane product/service search modal.
// Left side: search results list with filter pills. Right side: live preview.
// Arrow keys to navigate, Enter to add to order, click to select/preview.
// Results and previews are rendered server-side and fetched as HTML.
export default class extends Controller {
  static targets = ["input", "results", "preview", "filterBar"]
  static values = { orderId: Number }

  connect() {
    this.selectedIndex = -1
    this.searchResults = []
    this.debounceTimer = null
    this.activeFilter = "all"
    this.previewKey = null

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
      this.showPlaceholder()
      return
    }
    this.performSearch(query)
  }

  showPlaceholder() {
    this.resultsTarget.innerHTML = '<div class="p-6 text-center text-sm text-muted">Type to search for products or services</div>'
    this.clearPreview()
    this.searchResults = []
    this.selectedIndex = -1
  }

  async performSearch(query) {
    try {
      let url = `/search/product_results?q=${encodeURIComponent(query)}&limit=20`
      if (this.activeFilter !== "all") {
        url += `&type=${encodeURIComponent(this.activeFilter)}`
      }
      url += `&selected=0`

      const response = await fetch(url, {
        headers: { "Accept": "text/html" }
      })

      if (response.ok) {
        const html = await response.text()
        await this.swapResults(html)

        // Parse the results from the DOM to update state
        this.refreshSearchResultsFromDom()
        this.selectedIndex = this.searchResults.length > 0 ? 0 : -1

        if (this.selectedIndex >= 0) {
          const firstResult = this.searchResults[0]
          this.loadPreview(firstResult.type, firstResult.id)
        } else {
          this.clearPreview()
        }
      } else {
        await this.swapResults('<div class="p-6 text-center text-sm text-red-500">Search failed</div>')
      }
    } catch (e) {
      await this.swapResults('<div class="p-6 text-center text-sm text-red-500">Search failed</div>')
    }
  }

  async swapResults(html) {
    const el = this.resultsTarget
    el.innerHTML = html
  }

  refreshSearchResultsFromDom() {
    // Parse the current results from the DOM to rebuild searchResults array
    this.searchResults = []
    const buttons = this.resultsTarget.querySelectorAll('[data-type][data-id]')
    buttons.forEach((btn, idx) => {
      this.searchResults.push({
        type: btn.dataset.type,
        id: btn.dataset.id,
        index: idx
      })
    })
  }

  updateSelectionDisplay() {
    // Update visual selection in the DOM
    const buttons = this.resultsTarget.querySelectorAll('[data-type][data-id]')
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
        btn.classList.remove("bg-accent/20", "border-l-4", "border-l-accent")
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
      const result = this.searchResults[this.selectedIndex]
      if (result) this.loadPreview(result.type, result.id)
    } else if (event.key === "ArrowUp") {
      event.preventDefault()
      this.selectedIndex = Math.max(this.selectedIndex - 1, 0)
      this.updateSelectionDisplay()
      const result = this.searchResults[this.selectedIndex]
      if (result) this.loadPreview(result.type, result.id)
    } else if (event.key === "Enter" && this.selectedIndex >= 0) {
      event.preventDefault()
      const result = this.searchResults[this.selectedIndex]
      if (result) this.addToOrder(result.type, result.id)
    }
  }

  selectItem(event) {
    const btn = event.currentTarget
    const idx = parseInt(btn.dataset.index, 10)
    this.selectedIndex = idx
    this.updateSelectionDisplay()
    this.loadPreview(btn.dataset.type, btn.dataset.id)
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

  async loadPreview(type, id) {
    if (!this.hasPreviewTarget) return
    const key = `${type}-${id}`
    if (key === this.previewKey) return
    this.previewKey = key

    try {
      const url = type === "Product" ? `/products/${id}/preview` : `/services/${id}/preview`
      const response = await fetch(url, { headers: { "Accept": "text/html" } })
      const html = response.ok
        ? this.wrapPreviewWithAddButton(await response.text(), type, id)
        : this.basicPreviewHtml(type, id)
      await this.swapPreview(html)
    } catch {
      await this.swapPreview(this.basicPreviewHtml(type, id))
    }
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

  wrapPreviewWithAddButton(html, type, id) {
    // Add the "Add to Order" button wrapper around the server-rendered preview
    return `
      ${html}
      <div class="px-5 pb-5 border-t border-theme pt-3">
        <button type="button"
                class="w-full rounded-lg bg-accent px-4 py-2 text-xs font-semibold text-white hover:bg-(--color-accent-hover) transition"
                data-action="click->product-search#addPreviewItem"
                data-type="${type}"
                data-id="${id}">
          Add to Order
        </button>
        <p class="mt-2 text-center text-[10px] text-muted">Or press Enter, or double-click the result</p>
      </div>`
  }

  basicPreviewHtml(type, id) {
    return `
      <div class="p-5 space-y-4">
        <p class="text-xs text-muted">Detailed preview unavailable for this item.</p>
        <div class="border-t border-theme pt-3">
          <button type="button"
                  class="w-full rounded-lg bg-accent px-4 py-2 text-xs font-semibold text-white hover:bg-(--color-accent-hover) transition"
                  data-action="click->product-search#addPreviewItem"
                  data-type="${type}"
                  data-id="${id}">
            Add to Order
          </button>
        </div>
      </div>`
  }

  addPreviewItem(event) {
    const type = event.currentTarget.dataset.type
    const id = event.currentTarget.dataset.id
    this.addToOrder(type, id)
  }

  clearPreview() {
    if (!this.hasPreviewTarget) return
    this.swapPreview(`
      <div class="flex h-full items-center justify-center p-6">
        <div class="text-center">
          <svg class="mx-auto h-10 w-10 text-muted opacity-30" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="1.5" d="M15 12a3 3 0 11-6 0 3 3 0 016 0z"/><path stroke-linecap="round" stroke-linejoin="round" stroke-width="1.5" d="M2.458 12C3.732 7.943 7.523 5 12 5c4.478 0 8.268 2.943 9.542 7-1.274 4.057-5.064 7-9.542 7-4.477 0-8.268-2.943-9.542-7z"/></svg>
          <p class="mt-2 text-xs text-muted">Select an item to preview</p>
        </div>
      </div>`)
  }

  close() {
    this.element.classList.add("hidden")
    this.inputTarget.value = ""
    this.searchResults = []
    this.selectedIndex = -1
    this.activeFilter = "all"
    this.previewKey = null
    this.updateFilterPills()
    this.showPlaceholder()

    const codeInput = document.getElementById("code_lookup_input")
    if (codeInput) codeInput.focus()
  }
}
