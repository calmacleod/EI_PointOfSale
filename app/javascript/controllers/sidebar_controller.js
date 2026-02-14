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
    const wasExpanded = this.sidebarTarget.classList.contains("sidebar-expanded")

    this.element.classList.toggle("sidebar-collapsed", collapsed)
    this.sidebarTarget.classList.toggle("sidebar-mini", collapsed)
    this.sidebarTarget.classList.toggle("sidebar-expanded", !collapsed)

    if (collapsed) {
      if (wasExpanded) {
        this.scheduleHideTextAfterTransition()
      } else {
        this.sidebarTarget.classList.add("sidebar-mini-hide-text")
      }
    } else {
      this.sidebarTarget.classList.remove("sidebar-mini-hide-text")
    }
  }

  scheduleHideTextAfterTransition() {
    const handler = (event) => {
      if (event.propertyName === "width") {
        this.sidebarTarget.removeEventListener("transitionend", handler)
        this.sidebarTarget.classList.add("sidebar-mini-hide-text")
      }
    }
    this.sidebarTarget.addEventListener("transitionend", handler)
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

  // Navigate on mousedown for snappy feel (don't wait for click/mouseup)
  navigate(event) {
    const link = event.target.closest("a")
    if (!link?.href) return
    if (event.button !== 0) return
    if (event.ctrlKey || event.metaKey || event.shiftKey) return
    if (link.target === "_blank") return
    if (!link.href.startsWith(window.location.origin)) return

    event.preventDefault()
    if (!this.isDesktop()) this.closeMobileDrawer()
    Turbo.visit(link.href)
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
