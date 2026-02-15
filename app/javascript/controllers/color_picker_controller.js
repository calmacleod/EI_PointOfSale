import { Controller } from "@hotwired/stimulus"

// Manages accent-color swatch selection in admin settings.
// Clicking a swatch updates the hidden input and visual selection state.
export default class extends Controller {
  static targets = ["input", "swatch"]

  select(event) {
    const color = event.currentTarget.dataset.color
    this.inputTarget.value = color

    this.swatchTargets.forEach((el) => {
      const isSelected = el.dataset.color === color
      el.setAttribute("aria-checked", isSelected)
      el.classList.toggle("ring-2", isSelected)
      el.classList.toggle("ring-offset-1", isSelected)

      // Toggle the checkmark icon
      const check = el.querySelector("[data-check]")
      if (check) check.classList.toggle("hidden", !isSelected)
    })
  }
}
