import { Controller } from "@hotwired/stimulus"
import { createConsumer } from "@rails/actioncable"

// Singleton subscription manager to persist across page navigations
// This prevents constant subscribe/unsubscribe cycles as user navigates the app
class NotificationSubscriptionManager {
  static instance = null
  static subscribers = new Set()

  static getInstance() {
    if (!this.instance) {
      this.instance = new NotificationSubscriptionManager()
    }
    return this.instance
  }

  constructor() {
    this.consumer = createConsumer()
    this.channel = this.consumer.subscriptions.create(
      { channel: "NotificationChannel" },
      { received: (data) => this.broadcast(data) }
    )
  }

  subscribe(callback) {
    this.subscribers.add(callback)
    return () => this.subscribers.delete(callback)
  }

  broadcast(data) {
    this.subscribers.forEach(callback => callback(data))
  }
}

export default class extends Controller {
  static targets = ["badge", "toastContainer", "popover"]

  connect() {
    // Subscribe to the singleton manager instead of creating a new subscription
    this.unsubscribe = NotificationSubscriptionManager.getInstance().subscribe(
      (data) => this.handleNotification(data)
    )
    this.dropdownOpen = false
  }

  disconnect() {
    // Unsubscribe from the manager but keep the underlying subscription alive
    this.unsubscribe?.()
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

  updateBadgeCount(count) {
    if (!this.hasBadgeTarget) return
    this.badgeTargets.forEach((badge) => {
      badge.textContent = String(count)
      if (count === 0) {
        badge.classList.add("hidden")
      } else {
        badge.classList.remove("hidden")
      }
    })
  }

  toggleDropdown(event) {
    event.stopPropagation()
    const button = event.currentTarget

    if (this.dropdownOpen) {
      this.closePopover()
      return
    }

    if (!this.hasPopoverTarget) return

    const rect = button.getBoundingClientRect()
    const isSidebar = button.closest("aside") !== null

    // Position the popover
    if (isSidebar) {
      // Position to the right of sidebar button
      this.popoverTarget.style.left = `${rect.right + 8}px`
      this.popoverTarget.style.bottom = `${window.innerHeight - rect.bottom}px`
      this.popoverTarget.style.top = "auto"
      this.popoverTarget.style.right = "auto"
    } else {
      // Mobile: position below button
      this.popoverTarget.style.left = "auto"
      this.popoverTarget.style.right = `${window.innerWidth - rect.right}px`
      this.popoverTarget.style.top = `${rect.bottom + 4}px`
      this.popoverTarget.style.bottom = "auto"
    }

    this.popoverTarget.classList.remove("hidden")
    this.dropdownOpen = true

    // Reload the frame to refresh notifications
    const frame = this.popoverTarget.querySelector("turbo-frame")
    if (frame) {
      frame.src = "/notifications"
    }

    // Setup event delegation for actions within the popover
    this.popoverTarget.addEventListener("click", this.handlePopoverClick)

    // Close on click outside
    this.boundCloseOnClickOutside = (e) => {
      if (!this.popoverTarget.contains(e.target) && !button.contains(e.target)) {
        this.closePopover()
      }
    }
    setTimeout(() => document.addEventListener("click", this.boundCloseOnClickOutside), 0)
  }

  handlePopoverClick = (e) => {
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
  }

  closePopover() {
    if (this.hasPopoverTarget) {
      this.popoverTarget.classList.add("hidden")
      this.popoverTarget.removeEventListener("click", this.handlePopoverClick)
    }
    this.dropdownOpen = false

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
    }).then(response => response.json())
      .then(data => {
        this.updateBadgeCount(data.unread_count)
      }).catch(() => {})
  }

  markAllReadAndRefresh() {
    const csrfToken = document.querySelector('meta[name="csrf-token"]')?.content
    fetch("/notifications/mark_all_read", {
      method: "PATCH",
      headers: { "X-CSRF-Token": csrfToken, "Accept": "application/json" },
      credentials: "same-origin"
    }).then(response => response.json())
      .then(data => {
        this.updateBadgeCount(data.unread_count)
        this.refreshPopover()
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
      this.updateBadgeCount(0)
      this.refreshPopover()
    }).catch(() => {})
  }

  refreshPopover() {
    if (this.hasPopoverTarget) {
      const frame = this.popoverTarget.querySelector("turbo-frame")
      if (frame) frame.src = "/notifications"
    }
  }
}
