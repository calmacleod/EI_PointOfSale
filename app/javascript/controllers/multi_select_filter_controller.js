import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["label", "dropdown"]

  connect() {
    this.boundClose = this.closeOnOutsideClick.bind(this)
    document.addEventListener("click", this.boundClose)
  }

  disconnect() {
    document.removeEventListener("click", this.boundClose)
  }

  toggle(event) {
    event.stopPropagation()
    if (this.hasDropdownTarget) {
      this.dropdownTarget.classList.toggle("hidden")
    }
  }

  changed() {
    this.updateLabel()
  }

  updateLabel() {
    if (!this.hasLabelTarget) return

    const checked = this.element.querySelectorAll("input[type=checkbox]:checked")
    if (checked.length === 0) {
      this.labelTarget.textContent = "Select\u2026"
    } else {
      const count = checked.length
      this.labelTarget.textContent = `${count} selected`
    }
  }

  closeOnOutsideClick(event) {
    if (!this.hasDropdownTarget) return
    if (this.element.contains(event.target)) return
    this.dropdownTarget.classList.add("hidden")
  }
}
