import { Controller } from "@hotwired/stimulus"

/**
 * Manages the "Saved queries" dropdown in the filter bar.
 * Handles saving current filters, loading saved queries, and deleting them.
 */
export default class extends Controller {
  static targets = ["dropdown", "nameInput", "list", "emptyMessage"]
  static values = {
    resource: String,
    searchPath: String
  }

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

  closeOnOutsideClick(event) {
    if (!this.hasDropdownTarget) return
    if (this.element.contains(event.target)) return
    this.dropdownTarget.classList.add("hidden")
  }

  async save() {
    if (!this.hasNameInputTarget) return
    const name = this.nameInputTarget.value.trim()
    if (!name) return

    // Gather current filter params from the URL
    const urlParams = new URLSearchParams(window.location.search)
    const queryParams = {}
    for (const [key, value] of urlParams) {
      if (value) queryParams[key] = value
    }

    const csrfToken = document.querySelector("meta[name=csrf-token]")?.content
    try {
      const response = await fetch("/saved_queries", {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "X-CSRF-Token": csrfToken,
          "Accept": "text/vnd.turbo-stream.html"
        },
        body: JSON.stringify({
          saved_query: {
            name: name,
            resource_type: this.resourceValue,
            query_params: queryParams
          }
        })
      })

      if (response.ok) {
        const html = await response.text()
        // Process turbo stream or manually append
        if (html.includes("turbo-stream")) {
          Turbo.renderStreamMessage(html)
        }
        this.nameInputTarget.value = ""

        // Hide empty message if present
        if (this.hasEmptyMessageTarget) {
          this.emptyMessageTarget.classList.add("hidden")
        }
      }
    } catch (_e) {
      // Silently fail
    }
  }
}
