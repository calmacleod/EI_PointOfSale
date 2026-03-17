import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["label", "dropdown", "search", "list"]

  connect() {
    this.boundClose = this.closeOnOutsideClick.bind(this)
    document.addEventListener("click", this.boundClose)
  }

  disconnect() {
    document.removeEventListener("click", this.boundClose)
  }

  toggle(event) {
    event.stopPropagation()
    if (!this.hasDropdownTarget) return

    const isNowHidden = this.dropdownTarget.classList.toggle("hidden")
    if (!isNowHidden && this.hasSearchTarget) {
      this.searchTarget.value = ""
      this.filterOptions()
      this.searchTarget.focus()
    }
  }

  filterOptions() {
    if (!this.hasListTarget) return

    const query = this.hasSearchTarget ? this.searchTarget.value.toLowerCase() : ""
    this.listTarget.querySelectorAll("label").forEach(label => {
      label.hidden = query.length > 0 && !label.textContent.toLowerCase().includes(query)
    })
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
    if (this.hasSearchTarget) {
      this.searchTarget.value = ""
      this.filterOptions()
    }
  }
}
