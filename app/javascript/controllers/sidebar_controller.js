import { Controller } from "@hotwired/stimulus"

const SIDEBAR_WIDTH = 224
const EDGE_ZONE = 24
const VELOCITY_THRESHOLD = 0.3

export default class extends Controller {
  static targets = ["sidebar", "overlay"]
  static values = {
    collapsed: { type: Boolean, default: false },
    profilePath: String
  }

  connect() {
    this.applyCollapsedState()
    if (!this.isDesktop()) {
      this.boundTouchStart = this.handleTouchStart.bind(this)
      this.boundTouchMove = this.handleTouchMove.bind(this)
      this.boundTouchEnd = this.handleTouchEnd.bind(this)
      this.boundTouchCancel = this.handleTouchEnd.bind(this)
      document.addEventListener("touchstart", this.boundTouchStart, { passive: true })
      document.addEventListener("touchmove", this.boundTouchMove, { passive: false })
      document.addEventListener("touchend", this.boundTouchEnd, { passive: true })
      document.addEventListener("touchcancel", this.boundTouchCancel, { passive: true })
    }
  }

  disconnect() {
    if (this.boundTouchStart) {
      document.removeEventListener("touchstart", this.boundTouchStart)
      document.removeEventListener("touchmove", this.boundTouchMove)
      document.removeEventListener("touchend", this.boundTouchEnd)
      document.removeEventListener("touchcancel", this.boundTouchCancel)
    }
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
        if (this.sidebarTarget.classList.contains("sidebar-mini")) {
          this.sidebarTarget.classList.add("sidebar-mini-hide-text")
        }
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

  isMobileDrawerOpen() {
    return this.sidebarTarget.classList.contains("translate-x-0")
  }

  handleTouchStart(event) {
    if (this.isDesktop()) return
    const touch = event.touches[0]
    if (!touch) return

    const x = touch.clientX
    const y = touch.clientY
    const isClosed = this.sidebarTarget.classList.contains("-translate-x-full")
    const isOpen = this.isMobileDrawerOpen()

    const edgeSwipeToOpen = isClosed && x < EDGE_ZONE
    const swipeToClose = isOpen && x >= SIDEBAR_WIDTH // Only capture on overlay; touches on sidebar allow scroll

    if (edgeSwipeToOpen || swipeToClose) {
      this.swipeState = {
        startX: x,
        startY: y,
        startTime: Date.now(),
        isOpening: edgeSwipeToOpen
      }
    }
  }

  handleTouchMove(event) {
    if (!this.swipeState) return
    if (this.isDesktop()) return

    const touch = event.touches[0]
    if (!touch) return

    event.preventDefault()

    const x = touch.clientX
    const translateX = Math.max(-SIDEBAR_WIDTH, Math.min(0, x - SIDEBAR_WIDTH))

    this.sidebarTarget.style.transition = "none"
    this.sidebarTarget.style.transform = `translateX(${translateX}px)`

    if (this.hasOverlayTarget) {
      this.overlayTarget.classList.remove("hidden")
      this.overlayTarget.style.opacity = String((translateX + SIDEBAR_WIDTH) / SIDEBAR_WIDTH)
      document.body.classList.add("overflow-hidden")
    }
  }

  handleTouchEnd(event) {
    if (!this.swipeState) return
    if (this.isDesktop()) return

    const touch = event.changedTouches[0]
    if (!touch) {
      this.swipeState = null
      return
    }

    const x = touch.clientX
    const deltaX = x - this.swipeState.startX
    const deltaTime = Date.now() - this.swipeState.startTime
    const velocity = deltaTime > 0 ? deltaX / deltaTime : 0

    const currentTranslate = parseFloat(this.sidebarTarget.style.transform?.replace("translateX(", "").replace("px)", "")) || -SIDEBAR_WIDTH
    const openRatio = (currentTranslate + SIDEBAR_WIDTH) / SIDEBAR_WIDTH
    const totalMovement = Math.abs(deltaX)

    let shouldOpen
    if (this.swipeState.isOpening) {
      shouldOpen = openRatio > 0.25 || velocity > VELOCITY_THRESHOLD
    } else {
      shouldOpen = totalMovement < 10 ? false : openRatio > 0.75 || velocity > VELOCITY_THRESHOLD
    }

    this.sidebarTarget.style.transition = ""
    this.sidebarTarget.style.transform = ""

    if (shouldOpen) {
      this.sidebarTarget.classList.remove("-translate-x-full")
      this.sidebarTarget.classList.add("translate-x-0")
      if (this.hasOverlayTarget) {
        this.overlayTarget.classList.remove("hidden")
        this.overlayTarget.style.opacity = ""
        document.body.classList.add("overflow-hidden")
      }
    } else {
      this.sidebarTarget.classList.add("-translate-x-full")
      this.sidebarTarget.classList.remove("translate-x-0")
      if (this.hasOverlayTarget) {
        this.overlayTarget.classList.add("hidden")
        this.overlayTarget.style.opacity = ""
        document.body.classList.remove("overflow-hidden")
      }
    }

    this.swipeState = null
  }
}
