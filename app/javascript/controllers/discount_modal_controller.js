import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["orderPanel", "linesPanel", "modeTab", "lineQty"]

  setMode(event) {
    const mode = event.currentTarget.dataset.mode
    const isOrder = mode === "order"

    this.orderPanelTarget.classList.toggle("hidden", !isOrder)
    this.linesPanelTarget.classList.toggle("hidden", isOrder)

    this.modeTabTargets.forEach(tab => {
      const active = tab.dataset.mode === mode
      tab.classList.toggle("border-accent", active)
      tab.classList.toggle("text-accent", active)
      tab.classList.toggle("border-transparent", !active)
      tab.classList.toggle("text-muted", !active)
    })
  }

  // Intercept the Specific Items form submit to inject hidden inputs
  // encoding how many units per line should receive the discount.
  buildLineInputs(event) {
    const form = event.target

    // Remove any previously generated inputs
    form.querySelectorAll("[data-generated]").forEach(el => el.remove())

    // Read quantity from each line input
    this.lineQtyTargets.forEach(input => {
      const lineId = input.dataset.lineId
      const count = parseInt(input.value, 10) || 0
      if (count > 0) {
        const hidden = document.createElement("input")
        hidden.type = "hidden"
        hidden.name = `order_line_discount[line_quantities][${lineId}]`
        hidden.value = count
        hidden.dataset.generated = "true"
        form.appendChild(hidden)
      }
    })
  }

  close() {
    this.element.innerHTML = ""
  }

  submitEnd(event) {
    if (event.detail.success) {
      this.close()
    }
  }
}
