import { router } from "@inertiajs/react"

export default function TabBar({ activeOrders, currentOrderId, heldCount, newOrderUrl, registerUrl }) {
  function navigate(orderId) {
    router.visit(`${registerUrl}?order_id=${orderId}`, { preserveScroll: false })
  }

  return (
    <div className="flex shrink-0 items-center gap-1 overflow-x-auto border-b border-theme bg-surface px-2 py-1">
      {activeOrders.map((order) => (
        <button
          key={order.id}
          type="button"
          onClick={() => navigate(order.id)}
          className={`flex shrink-0 items-center gap-1.5 rounded px-2 py-1 text-xs transition-colors ${
            order.id === currentOrderId
              ? "bg-accent text-white"
              : "bg-page text-body hover:bg-(--color-border)"
          }`}
        >
          <span className="font-medium">{order.number}</span>
          {order.customer_name !== "Quick Sale" && (
            <span className="text-[10px] opacity-75 max-w-[6rem] truncate">{order.customer_name}</span>
          )}
          {order.line_count > 0 && (
            <span className={`rounded-full px-1 text-[10px] font-bold ${order.id === currentOrderId ? "bg-white/20" : "bg-(--color-border)"}`}>
              {order.line_count}
            </span>
          )}
          {order.status === "held" && (
            <span className="rounded bg-amber-100 px-1 text-[10px] font-medium text-amber-700">hold</span>
          )}
        </button>
      ))}

      <button
        type="button"
        onClick={() => router.post(newOrderUrl)}
        className="flex shrink-0 items-center gap-1 rounded px-2 py-1 text-xs text-muted hover:bg-(--color-border)"
      >
        <svg className="h-3 w-3" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 4v16m8-8H4" />
        </svg>
        New
      </button>

      {heldCount > 0 && (
        <a
          href="/orders/held"
          data-turbo="false"
          className="ml-auto flex shrink-0 items-center gap-1 rounded px-2 py-1 text-xs text-muted hover:bg-(--color-border)"
        >
          <span className="rounded-full bg-amber-100 px-1.5 text-[10px] font-bold text-amber-700">{heldCount}</span>
          Held
        </a>
      )}
    </div>
  )
}
