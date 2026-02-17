import { Controller } from "@hotwired/stimulus"

// Modal-based customer search for assigning a customer to an order.
// Searches by name, phone, email, or member number with filter pills.
export default class extends Controller {
  static targets = ["input", "results", "filterBar"]
  static values = { orderId: Number }

  connect() {
    this.debounceTimer = null
    this.selectedIndex = -1
    this.customerResults = []
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
    this.debounceTimer = setTimeout(() => this.triggerSearch(), 200)
  }

  triggerSearch() {
    const query = this.inputTarget.value.trim()
    if (query.length < 1) {
      this.resultsTarget.innerHTML = '<div class="p-6 text-center text-sm text-muted">Type to search for customers</div>'
      return
    }
    this.performSearch(query)
  }

  async performSearch(query) {
    try {
      let url = `/customers/search.json?q=${encodeURIComponent(query)}`
      if (this.activeFilter !== "all") {
        url += `&filter=${encodeURIComponent(this.activeFilter)}`
      }
      const response = await fetch(url)
      if (!response.ok) throw new Error(`HTTP ${response.status}`)
      const data = await response.json()
      this.customerResults = data.results || []
      this.selectedIndex = this.customerResults.length > 0 ? 0 : -1
      this.renderResults()
    } catch (e) {
      console.error("Customer search failed:", e)
      this.resultsTarget.innerHTML = '<div class="p-6 text-center text-sm text-red-500">Search failed. Please try again.</div>'
    }
  }

  renderResults() {
    if (this.customerResults.length === 0) {
      this.resultsTarget.innerHTML = `
        <div class="p-6 text-center">
          <p class="text-sm text-muted">No customers found</p>
          <p class="mt-1 text-xs text-muted">Try a different name, phone, email, or member #</p>
        </div>`
      return
    }

    const html = this.customerResults.map((c, idx) => {
      const selected = idx === this.selectedIndex
      const bgClass = selected ? "bg-accent/10 border-l-2 border-l-accent" : "border-l-2 border-l-transparent"

      const details = [
        c.member_number ? `#${this.esc(c.member_number)}` : null,
        c.phone ? this.esc(c.phone) : null,
        c.email ? this.esc(c.email) : null
      ].filter(Boolean)

      const badges = []
      if (!c.active) badges.push(`<span class="rounded-full bg-gray-100 px-1.5 py-0.5 text-[10px] font-medium text-gray-600">Inactive</span>`)
      if (c.has_tax_code) badges.push(`<span class="rounded-full bg-blue-100 px-1.5 py-0.5 text-[10px] font-medium text-blue-700">${this.esc(c.tax_code_name)}</span>`)
      if (c.has_alert) badges.push(`<span class="rounded-full bg-yellow-100 px-1.5 py-0.5 text-[10px] font-medium text-yellow-700">Alert</span>`)

      return `
        <button type="button"
                class="flex w-full items-center justify-between px-4 py-3 text-left hover:bg-[var(--color-border)] transition ${bgClass}"
                data-action="click->customer-search#selectCustomer"
                data-customer-id="${c.id}">
          <div class="min-w-0 flex-1">
            <div class="flex items-center gap-2">
              <span class="text-sm font-medium text-body">${this.esc(c.name)}</span>
              ${badges.length ? `<div class="flex gap-1">${badges.join("")}</div>` : ""}
            </div>
            ${details.length ? `<p class="mt-0.5 text-xs text-muted truncate">${details.join(" · ")}</p>` : ""}
          </div>
          <svg class="h-4 w-4 shrink-0 text-muted opacity-50" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5l7 7-7 7"/></svg>
        </button>`
    }).join("")

    this.resultsTarget.innerHTML = html

    const selectedBtn = this.resultsTarget.children[this.selectedIndex]
    if (selectedBtn) selectedBtn.scrollIntoView({ block: "nearest" })
  }

  navigate(event) {
    const len = this.customerResults.length
    if (len === 0) return

    if (event.key === "ArrowDown") {
      event.preventDefault()
      this.selectedIndex = Math.min(this.selectedIndex + 1, len - 1)
      this.renderResults()
    } else if (event.key === "ArrowUp") {
      event.preventDefault()
      this.selectedIndex = Math.max(this.selectedIndex - 1, 0)
      this.renderResults()
    } else if (event.key === "Enter" && this.selectedIndex >= 0) {
      event.preventDefault()
      const c = this.customerResults[this.selectedIndex]
      if (c) this.assignCustomer(c.id)
    }
  }

  selectCustomer(event) {
    const customerId = event.currentTarget.dataset.customerId
    this.assignCustomer(customerId)
  }

  async assignCustomer(customerId) {
    const token = document.querySelector('meta[name="csrf-token"]')?.content
    const orderId = this.orderIdValue

    if (!orderId) return

    try {
      const response = await fetch(`/orders/${orderId}/assign_customer`, {
        method: "PATCH",
        headers: {
          "Content-Type": "application/x-www-form-urlencoded",
          "X-CSRF-Token": token,
          Accept: "text/vnd.turbo-stream.html"
        },
        body: `customer_id=${customerId}`
      })

      if (response.ok) {
        const html = await response.text()
        Turbo.renderStreamMessage(html)
        this.close()
      }
    } catch (e) {
      console.error("Failed to assign customer:", e)
    }
  }

  close() {
    this.element.classList.add("hidden")
    this.inputTarget.value = ""
    this.customerResults = []
    this.selectedIndex = -1
    this.activeFilter = "all"
    this.updateFilterPills()
    this.resultsTarget.innerHTML = '<div class="p-6 text-center text-sm text-muted">Type to search for customers</div>'

    const codeInput = document.getElementById("code_lookup_input")
    if (codeInput) codeInput.focus()
  }

  esc(text) {
    const div = document.createElement("div")
    div.textContent = text
    return div.innerHTML
  }
}
