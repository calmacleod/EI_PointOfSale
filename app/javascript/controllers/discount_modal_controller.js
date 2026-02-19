import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["orderPanel", "linesPanel", "modeTab", "unitBtn"]

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

  toggleUnit(event) {
    const btn = event.currentTarget
    const isActive = btn.dataset.active === "true"
    btn.dataset.active = isActive ? "false" : "true"

    if (isActive) {
      // Deselect: green → gray
      btn.classList.remove("bg-green-100", "text-green-700", "hover:bg-red-100", "hover:text-red-700")
      btn.classList.add("bg-gray-100", "text-gray-400", "hover:bg-green-100", "hover:text-green-700")
      btn.title = btn.title.replace("remove from", "apply to")
    } else {
      // Select: gray → green
      btn.classList.remove("bg-gray-100", "text-gray-400", "hover:bg-green-100", "hover:text-green-700")
      btn.classList.add("bg-green-100", "text-green-700", "hover:bg-red-100", "hover:text-red-700")
      btn.title = btn.title.replace("apply to", "remove from")
    }
  }

  // Intercept the Specific Items form submit to inject hidden inputs
  // encoding how many units per line should receive the discount.
  buildLineInputs(event) {
    const form = event.target

    // Remove any previously generated inputs
    form.querySelectorAll("[data-generated]").forEach(el => el.remove())

    // Tally active (selected) units per line
    const lineMap = {}
    this.unitBtnTargets.forEach(btn => {
      const lineId = btn.dataset.lineId
      if (!lineMap[lineId]) lineMap[lineId] = 0
      if (btn.dataset.active === "true") lineMap[lineId]++
    })

    // Append a hidden input for each line that has at least one selected unit
    Object.entries(lineMap).forEach(([lineId, count]) => {
      if (count > 0) {
        const input = document.createElement("input")
        input.type = "hidden"
        input.name = `order_line_discount[line_quantities][${lineId}]`
        input.value = count
        input.dataset.generated = "true"
        form.appendChild(input)
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
