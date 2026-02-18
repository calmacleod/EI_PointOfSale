import { Controller } from "@hotwired/stimulus"

// Modal-based customer search for assigning a customer to an order.
// Search results are rendered server-side via Turbo Streams.
// Placeholder is shown/hidden via Stimulus targets.
export default class extends Controller {
  static targets = ["input", "results", "filterBar", "form", "filterInput", "placeholder"]
  static values = { orderId: Number }

  connect() {
    this.debounceTimer = null
    this.selectedIndex = -1

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

  search() {
    if (this.debounceTimer) clearTimeout(this.debounceTimer)
    this.debounceTimer = setTimeout(() => this.submitSearch(), 200)
  }

  submitSearch() {
    const query = this.inputTarget.value.trim()
    if (query.length < 1) {
      this.showPlaceholder()
      return
    }
    this.hidePlaceholder()
    this.formTarget.requestSubmit()
  }

  showPlaceholder() {
    if (this.hasPlaceholderTarget) {
      this.placeholderTarget.classList.remove("hidden")
    }
    // Clear any search results
    const results = this.resultsTarget.querySelectorAll('.customer-search-result')
    results.forEach(r => r.remove())
  }

  hidePlaceholder() {
    if (this.hasPlaceholderTarget) {
      this.placeholderTarget.classList.add("hidden")
    }
  }

  onResultsLoaded() {
    this.selectedIndex = -1
    this.updateSelection()
    this.hidePlaceholder()
  }

  setFilter(event) {
    this.filterInputTarget.value = event.currentTarget.dataset.filter
    this.updateFilterPills()
    this.submitSearch()
  }

  updateFilterPills() {
    if (!this.hasFilterBarTarget) return
    const activeFilter = this.filterInputTarget.value
    this.filterBarTarget.querySelectorAll("button").forEach(btn => {
      const isActive = btn.dataset.filter === activeFilter
      btn.className = `rounded-full px-2.5 py-0.5 text-[11px] font-medium transition ${
        isActive ? "bg-accent text-white" : "text-muted hover:bg-[var(--color-border)]"
      }`
    })
  }

  navigate(event) {
    const buttons = this.resultButtons()
    if (buttons.length === 0) return

    if (event.key === "ArrowDown") {
      event.preventDefault()
      this.selectedIndex = Math.min(this.selectedIndex + 1, buttons.length - 1)
      this.updateSelection()
    } else if (event.key === "ArrowUp") {
      event.preventDefault()
      this.selectedIndex = Math.max(this.selectedIndex - 1, 0)
      this.updateSelection()
    } else if (event.key === "Enter" && this.selectedIndex >= 0) {
      event.preventDefault()
      const btn = buttons[this.selectedIndex]
      if (btn) this.assignCustomer(btn.dataset.customerId)
    }
  }

  resultButtons() {
    return this.hasResultsTarget
      ? [...this.resultsTarget.querySelectorAll(".customer-search-result")]
      : []
  }

  updateSelection() {
    this.resultButtons().forEach((btn, i) => {
      if (i === this.selectedIndex) {
        btn.classList.replace("border-l-transparent", "border-l-accent")
        btn.classList.add("bg-accent/10")
        btn.scrollIntoView({ block: "nearest" })
      } else {
        btn.classList.replace("border-l-accent", "border-l-transparent")
        btn.classList.remove("bg-accent/10")
      }
    })
  }

  selectCustomer(event) {
    this.assignCustomer(event.currentTarget.dataset.customerId)
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
    this.filterInputTarget.value = "all"
    this.selectedIndex = -1
    this.updateFilterPills()
    this.showPlaceholder()

    const codeInput = document.getElementById("code_lookup_input")
    if (codeInput) codeInput.focus()
  }
}
