import { Controller } from "@hotwired/stimulus"

const SIDEBAR_WIDTH = 224
const EDGE_ZONE = 28
const DIRECTION_LOCK_THRESHOLD = 10
const VELOCITY_THRESHOLD = 0.3
const SNAP_EASING = "cubic-bezier(0.2, 0, 0, 1)"
const SNAP_DURATION = "250ms"

export default class extends Controller {
  static targets = ["sidebar", "overlay"]
  static values = {
    collapsed: { type: Boolean, default: false },
    profilePath: String
  }

  connect() {
    this.applyCollapsedState()
    this.swipeState = null
    this.rafId = null
    this.setupTouchListeners()
  }

  disconnect() {
    this.teardownTouchListeners()
    if (this.rafId) cancelAnimationFrame(this.rafId)
  }

  setupTouchListeners() {
    this.boundTouchStart = this.handleTouchStart.bind(this)
    this.boundTouchMove = this.handleTouchMove.bind(this)
    this.boundTouchEnd = this.handleTouchEnd.bind(this)
    document.addEventListener("touchstart", this.boundTouchStart, { passive: true })
    document.addEventListener("touchmove", this.boundTouchMove, { passive: false })
    document.addEventListener("touchend", this.boundTouchEnd, { passive: true })
    document.addEventListener("touchcancel", this.boundTouchEnd, { passive: true })
  }

  teardownTouchListeners() {
    if (!this.boundTouchStart) return
    document.removeEventListener("touchstart", this.boundTouchStart)
    document.removeEventListener("touchmove", this.boundTouchMove)
    document.removeEventListener("touchend", this.boundTouchEnd)
    document.removeEventListener("touchcancel", this.boundTouchEnd)
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
    if (this.isMobileDrawerOpen()) {
      this.closeMobileDrawer()
    } else {
      this.openMobileDrawer()
    }
  }

  openMobileDrawer() {
    this.sidebarTarget.classList.remove("-translate-x-full")
    this.sidebarTarget.classList.add("translate-x-0")
    if (this.hasOverlayTarget) {
      this.overlayTarget.classList.remove("hidden")
      this.overlayTarget.style.opacity = ""
      document.body.classList.add("overflow-hidden")
    }
  }

  closeMobileDrawer() {
    this.sidebarTarget.classList.add("-translate-x-full")
    this.sidebarTarget.classList.remove("translate-x-0")
    if (this.hasOverlayTarget) {
      this.overlayTarget.classList.add("hidden")
      this.overlayTarget.style.opacity = ""
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

  // ── Touch gesture handling ──────────────────────────────────────────

  handleTouchStart(event) {
    if (this.isDesktop()) return
    const touch = event.touches[0]
    if (!touch) return

    const x = touch.clientX
    const isClosed = !this.isMobileDrawerOpen()
    const isOpen = this.isMobileDrawerOpen()

    const edgeSwipeToOpen = isClosed && x < EDGE_ZONE
    const swipeToClose = isOpen

    if (edgeSwipeToOpen || swipeToClose) {
      this.swipeState = {
        startX: x,
        startY: touch.clientY,
        lastX: x,
        startTime: Date.now(),
        isOpening: edgeSwipeToOpen,
        direction: null
      }
    }
  }

  handleTouchMove(event) {
    if (!this.swipeState) return
    if (this.isDesktop()) return

    const touch = event.touches[0]
    if (!touch) return

    const x = touch.clientX
    const y = touch.clientY
    const deltaX = x - this.swipeState.startX
    const deltaY = y - this.swipeState.startY

    if (!this.swipeState.direction) {
      const absDeltaX = Math.abs(deltaX)
      const absDeltaY = Math.abs(deltaY)

      if (absDeltaX < DIRECTION_LOCK_THRESHOLD && absDeltaY < DIRECTION_LOCK_THRESHOLD) {
        return
      }

      if (absDeltaY > absDeltaX) {
        this.swipeState = null
        return
      }

      this.swipeState.direction = "horizontal"
    }

    event.preventDefault()
    this.swipeState.lastX = x

    if (this.rafId) cancelAnimationFrame(this.rafId)
    this.rafId = requestAnimationFrame(() => {
      this.rafId = null
      this.applySwipePosition(x)
    })
  }

  applySwipePosition(x) {
    const translateX = Math.max(-SIDEBAR_WIDTH, Math.min(0, x - SIDEBAR_WIDTH))

    this.sidebarTarget.style.transition = "none"
    this.sidebarTarget.style.transform = `translateX(${translateX}px)`

    if (this.hasOverlayTarget) {
      const progress = (translateX + SIDEBAR_WIDTH) / SIDEBAR_WIDTH
      this.overlayTarget.classList.remove("hidden")
      this.overlayTarget.style.transition = "none"
      this.overlayTarget.style.opacity = String(Math.max(0, progress))
      document.body.classList.add("overflow-hidden")
    }
  }

  handleTouchEnd(event) {
    if (!this.swipeState) return
    if (this.isDesktop()) return

    if (this.rafId) {
      cancelAnimationFrame(this.rafId)
      this.rafId = null
    }

    if (!this.swipeState.direction) {
      this.swipeState = null
      return
    }

    const touch = event.changedTouches?.[0]
    const x = touch ? touch.clientX : this.swipeState.lastX
    const deltaX = x - this.swipeState.startX
    const deltaTime = Date.now() - this.swipeState.startTime
    const velocity = deltaTime > 0 ? deltaX / deltaTime : 0

    const currentTranslate = Math.max(-SIDEBAR_WIDTH, Math.min(0, x - SIDEBAR_WIDTH))
    const openRatio = (currentTranslate + SIDEBAR_WIDTH) / SIDEBAR_WIDTH

    let shouldOpen
    if (this.swipeState.isOpening) {
      shouldOpen = openRatio > 0.3 || velocity > VELOCITY_THRESHOLD
    } else {
      shouldOpen = openRatio > 0.5 && velocity > -VELOCITY_THRESHOLD
    }

    this.animateSnap(shouldOpen, currentTranslate)
    this.swipeState = null
  }

  animateSnap(shouldOpen, fromTranslate) {
    const targetTranslate = shouldOpen ? 0 : -SIDEBAR_WIDTH
    const targetOpacity = shouldOpen ? 1 : 0
    const distance = Math.abs(targetTranslate - fromTranslate)
    const durationMs = Math.max(100, Math.min(250, (distance / SIDEBAR_WIDTH) * 250))
    const duration = `${Math.round(durationMs)}ms`

    this.sidebarTarget.style.transition = `transform ${duration} ${SNAP_EASING}`
    this.sidebarTarget.style.transform = `translateX(${targetTranslate}px)`

    if (this.hasOverlayTarget) {
      this.overlayTarget.style.transition = `opacity ${duration} ${SNAP_EASING}`
      this.overlayTarget.style.opacity = String(targetOpacity)
    }

    const cleanup = () => {
      this.sidebarTarget.removeEventListener("transitionend", cleanup)
      this.sidebarTarget.style.transition = ""
      this.sidebarTarget.style.transform = ""

      if (shouldOpen) {
        this.sidebarTarget.classList.remove("-translate-x-full")
        this.sidebarTarget.classList.add("translate-x-0")
      } else {
        this.sidebarTarget.classList.add("-translate-x-full")
        this.sidebarTarget.classList.remove("translate-x-0")
      }

      if (this.hasOverlayTarget) {
        this.overlayTarget.style.transition = ""
        this.overlayTarget.style.opacity = ""
        if (shouldOpen) {
          this.overlayTarget.classList.remove("hidden")
          document.body.classList.add("overflow-hidden")
        } else {
          this.overlayTarget.classList.add("hidden")
          document.body.classList.remove("overflow-hidden")
        }
      }
    }

    this.sidebarTarget.addEventListener("transitionend", cleanup, { once: true })

    setTimeout(cleanup, durationMs + 50)
  }
}
