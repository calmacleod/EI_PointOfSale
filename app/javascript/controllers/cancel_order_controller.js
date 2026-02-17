import { Controller } from "@hotwired/stimulus"

// Manages a styled confirm modal for cancelling draft orders.
// Triggered from tab X buttons — populates the modal dynamically
// with the order number and cancel path before showing it.
export default class extends Controller {
  static targets = ["modal", "orderNumber", "form"]

  open(event) {
    event.preventDefault()
    event.stopPropagation()

    const btn = event.currentTarget
    const orderNumber = btn.dataset.orderNumber
    const cancelPath = btn.dataset.cancelPath

    this.orderNumberTarget.textContent = orderNumber
    this.formTarget.setAttribute("action", cancelPath)
    this.modalTarget.classList.remove("hidden")

    this.boundEscape = (e) => { if (e.key === "Escape") this.close() }
    document.addEventListener("keydown", this.boundEscape)

    // Focus the "Keep" button so Enter doesn't accidentally cancel
    const keepBtn = this.modalTarget.querySelector("[data-autofocus]")
    if (keepBtn) keepBtn.focus()
  }

  close() {
    this.modalTarget.classList.add("hidden")
    if (this.boundEscape) {
      document.removeEventListener("keydown", this.boundEscape)
    }
  }
}
