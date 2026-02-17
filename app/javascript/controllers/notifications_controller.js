import { Controller } from "@hotwired/stimulus"
import { createConsumer } from "@rails/actioncable"

export default class extends Controller {
  static targets = ["badge", "toastContainer"]

  connect() {
    this.consumer = createConsumer()
    this.channel = this.consumer.subscriptions.create(
      { channel: "NotificationChannel" },
      { received: (data) => this.handleNotification(data) }
    )
    this.dropdownOpen = false
  }

  disconnect() {
    this.channel?.unsubscribe()
    this.consumer?.disconnect()
    this.closePopover()
  }

  handleNotification(data) {
    // Handle badge updates for persistent notifications
    // Toast rendering is handled by Turbo Streams via turbo_stream_from
    if (data.persistent && this.hasBadgeTarget) {
      this.incrementBadge()
    }
  }

  dismissToast(event) {
    const toast = event.target.closest(".notification-toast")
    if (toast) {
      toast.style.opacity = "0"
      toast.style.transform = "translateX(100%)"
      setTimeout(() => toast.remove(), 300)
    }
  }

  incrementBadge() {
    if (!this.hasBadgeTarget) return
    this.badgeTargets.forEach((badge) => {
      const current = parseInt(badge.textContent, 10) || 0
      badge.textContent = String(current + 1)
      badge.classList.remove("hidden")
    })
  }

  toggleDropdown(event) {
    const button = event.currentTarget

    if (this.activePopover) {
      this.closePopover()
      return
    }

    const popover = document.createElement("div")
    popover.style.position = "fixed"
    popover.style.zIndex = "9999"
    popover.innerHTML = `<turbo-frame id="notifications_popover" src="/notifications" loading="eager"></turbo-frame>`

    const rect = button.getBoundingClientRect()
    const isSidebar = button.closest("aside") !== null

    if (isSidebar) {
      popover.style.left = `${rect.right + 8}px`
      popover.style.bottom = `${window.innerHeight - rect.bottom}px`
    } else {
      popover.style.right = `${window.innerWidth - rect.right}px`
      popover.style.top = `${rect.bottom + 4}px`
    }

    document.body.appendChild(popover)
    this.activePopover = popover

    popover.addEventListener("click", (e) => {
      const target = e.target.closest("[data-action]")
      if (!target) return

      const action = target.dataset.action
      if (action?.includes("markAllReadAndRefresh")) {
        e.preventDefault()
        this.markAllReadAndRefresh()
      } else if (action?.includes("clearAllNotifications")) {
        e.preventDefault()
        this.clearAllNotifications()
      } else if (action?.includes("dismissNotification")) {
        e.preventDefault()
        e.stopPropagation()
        const id = target.dataset.notificationId
        if (id) this.dismissNotificationById(id)
      } else if (action?.includes("markRead")) {
        const id = target.dataset.notificationId
        if (id) this.markReadById(id)
      }
    })

    this.boundCloseOnClickOutside = (e) => {
      if (!popover.contains(e.target) && !button.contains(e.target)) {
        this.closePopover()
      }
    }
    setTimeout(() => document.addEventListener("click", this.boundCloseOnClickOutside), 0)
  }

  closePopover() {
    if (this.activePopover) {
      this.activePopover.remove()
      this.activePopover = null
    }
    if (this.boundCloseOnClickOutside) {
      document.removeEventListener("click", this.boundCloseOnClickOutside)
      this.boundCloseOnClickOutside = null
    }
  }

  markRead(event) {
    const id = event.currentTarget?.dataset?.notificationId
    if (id) this.markReadById(id)
  }

  markReadById(id) {
    const csrfToken = document.querySelector('meta[name="csrf-token"]')?.content
    fetch(`/notifications/${id}/mark_read`, {
      method: "PATCH",
      headers: { "X-CSRF-Token": csrfToken, "Accept": "application/json" },
      credentials: "same-origin"
    }).catch(() => {})
  }

  markAllReadAndRefresh() {
    const csrfToken = document.querySelector('meta[name="csrf-token"]')?.content
    fetch("/notifications/mark_all_read", {
      method: "PATCH",
      headers: { "X-CSRF-Token": csrfToken, "Accept": "application/json" },
      credentials: "same-origin"
    }).then(() => {
      this.badgeTargets.forEach((badge) => {
        badge.textContent = "0"
        badge.classList.add("hidden")
      })

      if (this.activePopover) {
        const frame = this.activePopover.querySelector("turbo-frame")
        if (frame) frame.src = "/notifications"
      }
    }).catch(() => {})
  }

  dismissNotification(event) {
    event.preventDefault()
    event.stopPropagation()
    const id = event.currentTarget?.dataset?.notificationId
    if (id) this.dismissNotificationById(id)
  }

  dismissNotificationById(id) {
    const csrfToken = document.querySelector('meta[name="csrf-token"]')?.content
    fetch(`/notifications/${id}`, {
      method: "DELETE",
      headers: { "X-CSRF-Token": csrfToken, "Accept": "application/json" },
      credentials: "same-origin"
    }).then(() => this.refreshPopover()).catch(() => {})
  }

  clearAllNotifications() {
    const csrfToken = document.querySelector('meta[name="csrf-token"]')?.content
    fetch("/notifications/clear_all", {
      method: "DELETE",
      headers: { "X-CSRF-Token": csrfToken, "Accept": "application/json" },
      credentials: "same-origin"
    }).then(() => {
      this.badgeTargets.forEach((badge) => {
        badge.textContent = "0"
        badge.classList.add("hidden")
      })
      this.refreshPopover()
    }).catch(() => {})
  }

  refreshPopover() {
    if (this.activePopover) {
      const frame = this.activePopover.querySelector("turbo-frame")
      if (frame) frame.src = "/notifications"
    }
  }
}
