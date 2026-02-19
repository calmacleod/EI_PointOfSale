import { Controller } from "@hotwired/stimulus"

// Main orchestrator for the order edit form.
// Keeps the code input focused and handles keyboard shortcuts.
export default class extends Controller {
  static targets = ["codeInput"]
  static values = { orderId: Number }

  connect() {
    this.refocusInput()

    // Re-focus after Turbo Stream updates
    document.addEventListener("turbo:before-stream-render", this.boundRefocus = () => {
      requestAnimationFrame(() => this.refocusInput())
    })
  }

  disconnect() {
    document.removeEventListener("turbo:before-stream-render", this.boundRefocus)
  }

  refocusInput() {
    if (this.hasCodeInputTarget && !this.isModalOpen()) {
      this.codeInputTarget.focus()
    }
  }

  handleCodeKeydown(event) {
    if (event.key === "Escape") {
      event.target.value = ""
      event.preventDefault()
    }
  }

  handleLookup(event) {
    // Form submission is handled by Turbo
  }

  openSearch() {
    const modal = document.getElementById("product_search_modal")
    if (modal) {
      modal.classList.remove("hidden")
      const input = modal.querySelector("input[type=text]")
      if (input) {
        input.value = this.hasCodeInputTarget ? this.codeInputTarget.value : ""
        input.focus()
      }
    }
  }

  openCustomerSearch() {
    const modal = document.getElementById("customer_search_modal")
    if (modal) {
      modal.classList.remove("hidden")
      const input = modal.querySelector("input[type=text]")
      if (input) {
        input.value = ""
        input.focus()
      }
    }
  }

  saveNotes(event) {
    const form = event.target.closest("form")
    if (form) form.requestSubmit()
  }

  removeLine(event) {
    // Remove the row immediately for perceived responsiveness
    // Use setTimeout to allow the form submission to proceed
    setTimeout(() => {
      const row = event.target.closest("tr")
      if (row) {
        row.remove()
      }
    }, 0)
  }

  isModalOpen() {
    const modals = ["product_search_modal", "customer_search_modal", "item_preview_modal"]
    return modals.some(id => {
      const el = document.getElementById(id)
      return el && !el.classList.contains("hidden")
    })
  }
}
