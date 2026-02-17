import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["modal"]

  connect() {
    this.boundEscape = this.handleEscape.bind(this)
  }

  disconnect() {
    this.removeEscapeListener()
  }

  open(event) {
    const modalId = event.currentTarget.dataset.modalId
    const modal = document.getElementById(modalId)
    if (modal) {
      modal.classList.remove("hidden")
      document.body.classList.add("overflow-hidden")
      document.addEventListener("keydown", this.boundEscape)
    }
  }

  close() {
    this.modalTargets.forEach(modal => {
      modal.classList.add("hidden")
    })
    document.body.classList.remove("overflow-hidden")
    this.removeEscapeListener()
  }

  handleEscape(event) {
    if (event.key === "Escape") this.close()
  }

  removeEscapeListener() {
    document.removeEventListener("keydown", this.boundEscape)
  }
}
