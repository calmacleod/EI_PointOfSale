import { useState } from "react"
import { router } from "@inertiajs/react"
import { csrfToken } from "../../../lib/csrf"

export default function ActionButtons({ order, routes, onReload }) {
  const [notes, setNotes] = useState(order.notes || "")
  const isDraft = order.status === "draft"
  const isHeld = order.status === "held"
  const canComplete = isDraft && order.payment_complete && order.order_lines.length > 0

  async function saveNotes() {
    if (notes === order.notes) return
    await fetch(`/orders/${order.id}.json`, {
      method: "PATCH",
      headers: { "X-CSRF-Token": csrfToken(), "Content-Type": "application/json", Accept: "application/json" },
      body: JSON.stringify({ order: { notes } }),
    })
  }

  // Sync notes when order prop updates (after Inertia reload)
  if (notes !== order.notes && !document.activeElement?.classList?.contains("notes-input")) {
    // Only reset if not currently editing
  }

  return (
    <div className="p-3 space-y-2">
      <textarea
        className="notes-input w-full resize-none rounded border border-theme bg-page px-2 py-1.5 text-xs text-body placeholder-muted focus:border-accent focus:outline-none"
        rows={2}
        placeholder="Order notes..."
        value={notes}
        onChange={(e) => setNotes(e.target.value)}
        onBlur={saveNotes}
        disabled={!isDraft && !isHeld}
      />

      <div className="flex gap-2">
        {isDraft && (
          <button
            type="button"
            onClick={() => router.post(routes.hold)}
            className="flex-1 rounded border border-theme px-3 py-1.5 text-sm font-medium text-body hover:bg-(--color-border)"
          >
            Hold
          </button>
        )}
        {isHeld && (
          <button
            type="button"
            onClick={() => router.post(routes.resume)}
            className="flex-1 rounded border border-theme px-3 py-1.5 text-sm font-medium text-body hover:bg-(--color-border)"
          >
            Resume
          </button>
        )}
        {isDraft && (
          <button
            type="button"
            disabled={!canComplete}
            onClick={() => router.post(routes.complete)}
            className={`flex-1 rounded px-3 py-1.5 text-sm font-medium transition-colors ${
              canComplete
                ? "bg-accent text-white hover:bg-accent/90"
                : "cursor-not-allowed bg-(--color-border) text-muted"
            }`}
          >
            Complete
          </button>
        )}
      </div>
    </div>
  )
}
