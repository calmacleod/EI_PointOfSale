import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "checkbox",
    "selectAll",
    "count",
    "bulkForm",
    "searchInput",
    "typeFilter"
  ]

  static values = {
    selectionType: String
  }

  connect() {
    this.updateUI()
  }

  toggleSelectAll(event) {
    const isChecked = event.target.checked
    this.checkboxTargets.forEach(checkbox => {
      checkbox.checked = isChecked
    })
    this.updateUI()
  }

  toggleSelection() {
    this.updateUI()
  }

  updateUI() {
    const selectedCount = this.selectedCheckboxes.length

    // Update count display
    if (this.hasCountTarget) {
      this.countTarget.textContent = selectedCount
    }

    // Enable/disable bulk form submission
    if (this.hasBulkFormTarget) {
      const submitButton = this.bulkFormTarget.querySelector('button[type="submit"]')
      if (submitButton) {
        submitButton.disabled = selectedCount === 0
        submitButton.classList.toggle('opacity-50', selectedCount === 0)
        submitButton.classList.toggle('cursor-not-allowed', selectedCount === 0)
      }
    }

    // Update "select all" checkbox state
    if (this.hasSelectAllTarget && this.checkboxTargets.length > 0) {
      const allChecked = this.checkboxTargets.every(cb => cb.checked)
      const someChecked = this.checkboxTargets.some(cb => cb.checked)
      this.selectAllTarget.checked = allChecked
      this.selectAllTarget.indeterminate = someChecked && !allChecked
    }
  }

  search(event) {
    const query = event.target.value.trim()
    const typeFilter = this.hasTypeFilterTarget ? this.typeFilterTarget.value : 'all'

    // Trigger Turbo Frame reload with search params
    const frame = document.querySelector('turbo-frame[id*="search_results"]')
    if (frame) {
      const url = new URL(frame.src)
      if (query) {
        url.searchParams.set('q', query)
      } else {
        url.searchParams.delete('q')
      }
      if (typeFilter && typeFilter !== 'all') {
        url.searchParams.set('item_type', typeFilter)
      } else {
        url.searchParams.delete('item_type')
      }
      frame.src = url.toString()
    }
  }

  filterByType(event) {
    if (this.hasSearchInputTarget) {
      this.search({ target: this.searchInputTarget })
    }
  }

  submitBulkAdd(event) {
    event.preventDefault()

    const selectedItems = this.selectedCheckboxes.map(checkbox => ({
      id: checkbox.dataset.id,
      type: checkbox.dataset.type
    }))

    if (selectedItems.length === 0) return

    // Add hidden inputs for each selected item
    selectedItems.forEach(item => {
      const idInput = document.createElement('input')
      idInput.type = 'hidden'
      idInput.name = 'discountable_ids[]'
      idInput.value = item.id
      event.target.appendChild(idInput)

      const typeInput = document.createElement('input')
      typeInput.type = 'hidden'
      typeInput.name = 'discountable_types[]'
      typeInput.value = item.type
      event.target.appendChild(typeInput)
    })

    // Close the modal after submission by finding and clicking the close button
    const modal = this.element.closest('[data-modal-target="modal"]')
    if (modal) {
      const closeButton = modal.querySelector('[data-action="click->modal#close"]')
      if (closeButton) {
        // Add a small delay to let the form submission start, then close
        setTimeout(() => {
          closeButton.click()
        }, 100)
      }
    }

    event.target.submit()
  }

  get selectedCheckboxes() {
    return this.checkboxTargets.filter(checkbox => checkbox.checked)
  }
}
