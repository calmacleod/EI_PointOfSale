import { Controller } from "@hotwired/stimulus"

/**
 * Manages a date range filter chip's preset/custom toggle.
 * Shows custom from/to date fields when "Custom" is selected,
 * hides them for any preset value.
 */
export default class extends Controller {
  static targets = ["presetSelect", "customFields"]

  presetChanged() {
    if (!this.hasPresetSelectTarget || !this.hasCustomFieldsTarget) return

    const isCustom = this.presetSelectTarget.value === "custom"
    this.customFieldsTarget.classList.toggle("hidden", !isCustom)

    // When switching away from custom, clear the from/to date values
    if (!isCustom) {
      this.customFieldsTarget.querySelectorAll("input[type=date]").forEach(input => {
        input.value = ""
      })
    }
  }
}
