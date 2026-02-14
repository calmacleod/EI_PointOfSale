import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["sidebar", "overlay"]
  static values = {
    collapsed: { type: Boolean, default: false },
    profilePath: String
  }

  connect() {
    this.applyCollapsedState()
  }

  collapsedValueChanged() {
    this.applyCollapsedState()
  }

  applyCollapsedState() {
    const collapsed = this.collapsedValue
    this.element.classList.toggle("sidebar-collapsed", collapsed)
    this.sidebarTarget.classList.toggle("sidebar-mini", collapsed)
    this.sidebarTarget.classList.toggle("sidebar-expanded", !collapsed)
  }

  toggle() {
    if (this.isDesktop()) {
      this.toggleDesktopCollapsed()
    } else {
      this.toggleMobileDrawer()
    }
  }

  close() {
    if (!this.isDesktop()) {
      this.closeMobileDrawer()
    }
  }

  toggleMobileDrawer() {
    this.sidebarTarget.classList.toggle("-translate-x-full")
    this.sidebarTarget.classList.toggle("translate-x-0")
    if (this.hasOverlayTarget) {
      this.overlayTarget.classList.toggle("hidden")
      document.body.classList.toggle("overflow-hidden", !this.overlayTarget.classList.contains("hidden"))
    }
  }

  closeMobileDrawer() {
    this.sidebarTarget.classList.add("-translate-x-full")
    this.sidebarTarget.classList.remove("translate-x-0")
    if (this.hasOverlayTarget) {
      this.overlayTarget.classList.add("hidden")
      document.body.classList.remove("overflow-hidden")
    }
  }

  toggleDesktopCollapsed() {
    const newValue = !this.collapsedValue
    this.collapsedValue = newValue
    this.persistCollapsed(newValue)
  }

  persistCollapsed(value) {
    if (!this.profilePathValue) return

    const csrfToken = document.querySelector('meta[name="csrf-token"]')?.content
    const formData = new FormData()
    formData.append("user[sidebar_collapsed]", value)
    formData.append("authenticity_token", csrfToken)

    fetch(this.profilePathValue, {
      method: "PATCH",
      body: formData,
      headers: {
        "X-CSRF-Token": csrfToken,
        "Accept": "application/json, text/html",
        "X-Requested-With": "XMLHttpRequest"
      },
      credentials: "same-origin"
    }).catch(() => {})
  }

  isDesktop() {
    return window.matchMedia("(min-width: 1024px)").matches
  }
}
