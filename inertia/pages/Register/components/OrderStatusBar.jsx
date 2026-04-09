const STATUS_COLORS = {
  draft: "bg-blue-100 text-blue-700",
  held: "bg-amber-100 text-amber-700",
  completed: "bg-green-100 text-green-700",
  cancelled: "bg-red-100 text-red-700",
}

export default function OrderStatusBar({ order, onCancel }) {
  const isDraftOrHeld = order.status === "draft" || order.status === "held"

  return (
    <div className="flex shrink-0 items-center gap-3 border-b border-theme bg-surface px-3 py-2">
      <span className="text-sm font-semibold text-body">{order.number}</span>
      <span className={`rounded px-1.5 py-0.5 text-xs font-medium ${STATUS_COLORS[order.status] ?? "bg-(--color-border) text-body"}`}>
        {order.display_status}
      </span>
      <span className="text-xs text-muted">by {order.created_by.name}</span>

      <div className="ml-auto flex items-center gap-2">
        {isDraftOrHeld && (
          <button
            type="button"
            onClick={onCancel}
            className="rounded px-2 py-1 text-xs text-red-600 hover:bg-red-50"
          >
            Cancel Order
          </button>
        )}
      </div>
    </div>
  )
}
