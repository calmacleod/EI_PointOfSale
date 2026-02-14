import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["modal"]

  connect() {
    this.boundEscape = this.handleEscape.bind(this)
  }

  disconnect() {
    this.removeEscapeListener()
  }

  open() {
    this.modalTarget.classList.remove("hidden")
    document.body.classList.add("overflow-hidden")
    document.addEventListener("keydown", this.boundEscape)
    this.modalTarget.querySelector("[data-autofocus]")?.focus()
  }

  close() {
    this.modalTarget.classList.add("hidden")
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
