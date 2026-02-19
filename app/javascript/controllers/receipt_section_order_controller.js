import { Controller } from "@hotwired/stimulus"

/**
 * Enables drag-and-drop reordering of receipt template sections.
 * Updates a hidden JSON input with the new order and notifies the
 * receipt-preview controller to re-render the preview.
 */
export default class extends Controller {
  static targets = ["list", "input", "item"]

  connect() {
    this.draggedItem = null
  }

  // --- Drag handlers ---

  dragstart(event) {
    this.draggedItem = event.currentTarget.closest("[data-receipt-section-order-target='item']")
    event.dataTransfer.effectAllowed = "move"
    event.dataTransfer.setData("text/plain", this.draggedItem.dataset.sectionKey)
    requestAnimationFrame(() => this.draggedItem.classList.add("opacity-40"))
  }

  dragover(event) {
    event.preventDefault()
    event.dataTransfer.dropEffect = "move"

    const item = event.currentTarget.closest("[data-receipt-section-order-target='item']")
    if (!item || item === this.draggedItem) return

    const rect = item.getBoundingClientRect()
    const midpoint = rect.top + rect.height / 2

    if (event.clientY < midpoint) {
      item.parentNode.insertBefore(this.draggedItem, item)
    } else {
      item.parentNode.insertBefore(this.draggedItem, item.nextSibling)
    }
  }

  drop(event) {
    event.preventDefault()
    this.saveOrder()
  }

  dragend() {
    if (this.draggedItem) {
      this.draggedItem.classList.remove("opacity-40")
      this.draggedItem = null
    }
  }

  // --- Persistence & preview update ---

  saveOrder() {
    const order = this.itemTargets.map(item => item.dataset.sectionKey)
    this.inputTarget.value = JSON.stringify(order)
    // Notify the receipt-preview controller to re-render
    this.inputTarget.dispatchEvent(new Event("change", { bubbles: true }))
  }
}
