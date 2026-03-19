import { Controller } from "@hotwired/stimulus"

// Manages a dynamic restock list: add products by code or search, persist
// draft to localStorage, commit all rows at once.
export default class extends Controller {
  static targets = ["tbody", "summary", "submitBtn", "clearBtn", "csvModal", "searchModal", "form"]
  static values = { lookupUrl: String, storageKey: String }

  connect() {
    this.rows = [] // [{id, code, name, supplier, stockLevel, quantity, notes}]
    this.restoreFromStorage()
    this.ensureEmptyRow()

    // Listen for product selection from the search modal
    this.handleProductSelected = (event) => {
      this.addProductFromSearch(event.detail)
    }
    this.element.addEventListener("inventory-search:select", this.handleProductSelected)
  }

  disconnect() {
    this.element.removeEventListener("inventory-search:select", this.handleProductSelected)
  }

  // ── Row management ──────────────────────────────────────────────

  ensureEmptyRow() {
    const last = this.rows[this.rows.length - 1]
    if (!last || last.id) {
      this.rows.push({ id: null, code: "", name: "", supplier: "", stockLevel: null, quantity: "", notes: "" })
    }
    this.render()
  }

  addProductFromSearch(detail) {
    // Check if already in list
    const existing = this.rows.findIndex(r => r.id === detail.id)
    if (existing >= 0) {
      this.render()
      requestAnimationFrame(() => {
        const qtyInput = this.tbodyTarget.querySelector(`[data-row-index="${existing}"][data-field="quantity"]`)
        if (qtyInput) qtyInput.focus()
      })
      return
    }

    // Replace the empty entry row with this product
    const entryIdx = this.rows.findIndex(r => !r.id)
    if (entryIdx >= 0) {
      this.rows[entryIdx] = {
        id: detail.id,
        code: detail.code,
        name: detail.name,
        supplier: detail.supplier || "",
        stockLevel: detail.stockLevel,
        quantity: "",
        notes: ""
      }
    }
    this.saveToStorage()
    this.ensureEmptyRow()

    // Focus the quantity field of the newly added row
    const idx = entryIdx >= 0 ? entryIdx : this.rows.length - 2
    requestAnimationFrame(() => {
      const qtyInput = this.tbodyTarget.querySelector(`[data-row-index="${idx}"][data-field="quantity"]`)
      if (qtyInput) qtyInput.focus()
    })
  }

  async handleCodeKey(event) {
    if (event.key !== "Enter" && event.key !== "Tab") return
    event.preventDefault()

    const input = event.currentTarget
    const idx = parseInt(input.dataset.rowIndex)
    const code = input.value.trim()

    if (!code) return

    // Check for duplicate codes already in the list
    const existing = this.rows.findIndex((r, i) => i !== idx && r.code === code && r.id)
    if (existing >= 0) {
      input.value = ""
      this.rows[idx].code = ""
      this.render()
      const qtyInput = this.tbodyTarget.querySelector(`[data-row-index="${existing}"][data-field="quantity"]`)
      if (qtyInput) qtyInput.focus()
      return
    }

    try {
      const url = `${this.lookupUrlValue}?code=${encodeURIComponent(code)}`
      const response = await fetch(url, { headers: { "Accept": "application/json" } })
      const data = await response.json()

      if (data.found) {
        this.rows[idx] = {
          ...this.rows[idx],
          id: data.id,
          code: data.code,
          name: data.name,
          supplier: data.supplier || "",
          stockLevel: data.stock_level,
          quantity: this.rows[idx].quantity || "",
          notes: this.rows[idx].notes || ""
        }
        this.saveToStorage()
        this.ensureEmptyRow()
        requestAnimationFrame(() => {
          const qtyInput = this.tbodyTarget.querySelector(`[data-row-index="${idx}"][data-field="quantity"]`)
          if (qtyInput) qtyInput.focus()
        })
      } else {
        input.classList.add("border-red-400")
        input.setCustomValidity("Product not found")
        setTimeout(() => {
          input.classList.remove("border-red-400")
          input.setCustomValidity("")
        }, 2000)
      }
    } catch {
      // Network error — silently ignore
    }
  }

  handleCodeInput(event) {
    const idx = parseInt(event.currentTarget.dataset.rowIndex)
    this.rows[idx].code = event.currentTarget.value
  }

  handleQuantityInput(event) {
    const idx = parseInt(event.currentTarget.dataset.rowIndex)
    this.rows[idx].quantity = event.currentTarget.value
    this.saveToStorage()
    this.updateSummary()
  }

  handleNotesInput(event) {
    const idx = parseInt(event.currentTarget.dataset.rowIndex)
    this.rows[idx].notes = event.currentTarget.value
    this.saveToStorage()
  }

  removeRow(event) {
    const idx = parseInt(event.currentTarget.dataset.rowIndex)
    this.rows.splice(idx, 1)
    this.saveToStorage()
    this.ensureEmptyRow()
  }

  clearAll() {
    if (!confirm("Clear all restock items?")) return
    this.rows = []
    this.saveToStorage()
    this.ensureEmptyRow()
  }

  // ── Search modal ────────────────────────────────────────────────

  openSearch() {
    this.searchModalTarget.classList.remove("hidden")
    const input = this.searchModalTarget.querySelector("[data-inventory-search-target='input']")
    if (input) {
      // Pre-fill with any text from the code input
      const codeInput = this.tbodyTarget.querySelector("[data-field='code']")
      if (codeInput && codeInput.value.trim()) {
        input.value = codeInput.value.trim()
        input.dispatchEvent(new Event("input"))
      }
      requestAnimationFrame(() => input.focus())
    }
  }

  // ── Form submission ─────────────────────────────────────────────

  handleSubmit(event) {
    const form = this.formTarget
    form.querySelectorAll(".restock-hidden-fields").forEach(el => el.remove())

    const resolvedRows = this.rows.filter(r => r.id && parseInt(r.quantity) > 0)
    resolvedRows.forEach(row => {
      const container = document.createElement("div")
      container.className = "restock-hidden-fields"
      container.innerHTML = `
        <input type="hidden" name="restocks[][product_id]" value="${row.id}">
        <input type="hidden" name="restocks[][quantity]" value="${row.quantity}">
        <input type="hidden" name="restocks[][notes]" value="${row.notes || ""}">
      `
      form.appendChild(container)
    })

    if (resolvedRows.length === 0) {
      event.preventDefault()
      return
    }

    this.clearStorage()
  }

  // ── CSV modal ───────────────────────────────────────────────────

  openCsvModal() {
    this.csvModalTarget.classList.remove("hidden")
    this.csvModalTarget.classList.add("flex")
  }

  closeCsvModal() {
    this.csvModalTarget.classList.add("hidden")
    this.csvModalTarget.classList.remove("flex")
  }

  // ── Rendering ───────────────────────────────────────────────────

  render() {
    const html = this.rows.map((row, idx) => {
      const isEntry = !row.id

      if (isEntry) {
        return `
          <tr>
            <td class="px-3 py-1" colspan="5">
              <div class="flex items-center gap-2">
                <input type="text" placeholder="Enter product code…" autocomplete="off"
                       data-row-index="${idx}" data-field="code"
                       data-action="input->bulk-restock#handleCodeInput keydown->bulk-restock#handleCodeKey"
                       value="${this.escapeHtml(row.code)}"
                       class="w-44 rounded-md border border-theme bg-surface px-2 py-0.5 font-mono text-sm text-body placeholder:text-muted focus:border-accent focus:ring-1 focus:ring-accent">
                <span class="text-xs text-muted">or</span>
                <button type="button" data-action="click->bulk-restock#openSearch"
                        class="inline-flex items-center gap-1 rounded-md border border-theme bg-surface px-2 py-0.5 text-xs font-medium text-muted hover:bg-(--color-border)/30 hover:text-body">
                  <svg class="h-3 w-3" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z"/></svg>
                  Search
                </button>
              </div>
            </td>
            <td class="px-3 py-1"></td>
          </tr>`
      }

      const isLowStock = row.stockLevel !== null && row.stockLevel <= 0

      return `
        <tr class="${isLowStock ? "bg-red-50 dark:bg-red-950/20" : ""}">
          <td class="whitespace-nowrap px-3 py-1 font-mono text-xs text-body">${this.escapeHtml(row.code)}</td>
          <td class="px-3 py-1 text-body text-sm">${this.escapeHtml(row.name)}</td>
          <td class="whitespace-nowrap px-3 py-1 text-right text-sm text-muted">${row.stockLevel ?? "—"}</td>
          <td class="px-3 py-1 text-center">
            <input type="number" min="1" autocomplete="off"
                   data-row-index="${idx}" data-field="quantity"
                   data-action="input->bulk-restock#handleQuantityInput"
                   value="${this.escapeHtml(String(row.quantity || ""))}"
                   class="w-20 rounded-md border border-theme bg-surface px-2 py-0.5 text-center text-sm text-body focus:border-accent focus:ring-1 focus:ring-accent">
          </td>
          <td class="px-3 py-1">
            <input type="text" placeholder="Optional" autocomplete="off"
                   data-row-index="${idx}" data-field="notes"
                   data-action="input->bulk-restock#handleNotesInput"
                   value="${this.escapeHtml(row.notes || "")}"
                   class="w-full rounded-md border border-theme bg-surface px-2 py-0.5 text-sm text-body placeholder:text-muted focus:border-accent focus:ring-1 focus:ring-accent">
          </td>
          <td class="px-3 py-1 text-center">
            <button type="button" data-row-index="${idx}" data-action="click->bulk-restock#removeRow"
                    class="rounded p-0.5 text-muted hover:text-red-500" aria-label="Remove">
              <svg class="h-3.5 w-3.5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"/>
              </svg>
            </button>
          </td>
        </tr>`
    }).join("")

    this.tbodyTarget.innerHTML = html
    this.updateSummary()
  }

  updateSummary() {
    const resolved = this.rows.filter(r => r.id && parseInt(r.quantity) > 0)
    const count = resolved.length
    const totalQty = resolved.reduce((sum, r) => sum + parseInt(r.quantity || 0), 0)

    if (count === 0) {
      this.summaryTarget.textContent = "No items added yet"
      this.submitBtnTarget.disabled = true
      this.clearBtnTarget.classList.add("hidden")
      this.clearBtnTarget.classList.remove("inline-flex")
    } else {
      this.summaryTarget.textContent = `${count} product(s), ${totalQty} total units`
      this.submitBtnTarget.disabled = false
      this.clearBtnTarget.classList.remove("hidden")
      this.clearBtnTarget.classList.add("inline-flex")
    }
  }

  // ── Persistence ─────────────────────────────────────────────────

  saveToStorage() {
    try {
      const data = this.rows.filter(r => r.id)
      localStorage.setItem(this.storageKeyValue, JSON.stringify(data))
    } catch { /* storage unavailable */ }
  }

  restoreFromStorage() {
    try {
      const stored = localStorage.getItem(this.storageKeyValue)
      if (stored) {
        const data = JSON.parse(stored)
        if (Array.isArray(data) && data.length > 0) {
          this.rows = data
        }
      }
    } catch { /* storage unavailable */ }
  }

  clearStorage() {
    try {
      localStorage.removeItem(this.storageKeyValue)
    } catch { /* storage unavailable */ }
  }

  // ── Helpers ─────────────────────────────────────────────────────

  escapeHtml(str) {
    const div = document.createElement("div")
    div.textContent = str
    return div.innerHTML
  }
}
