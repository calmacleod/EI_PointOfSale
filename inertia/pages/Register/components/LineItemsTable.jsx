import LineItem from "./LineItem"

export default function LineItemsTable({ order, onReload }) {
  if (order.order_lines.length === 0) {
    return (
      <div className="flex flex-col items-center justify-center py-16 text-muted">
        <svg className="mb-3 h-10 w-10 opacity-30" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={1.5} d="M3 3h2l.4 2M7 13h10l4-8H5.4M7 13L5.4 5M7 13l-2.293 2.293c-.63.63-.184 1.707.707 1.707H17m0 0a2 2 0 100 4 2 2 0 000-4zm-8 2a2 2 0 11-4 0 2 2 0 014 0z" />
        </svg>
        <p className="text-sm">No items yet</p>
        <p className="text-xs opacity-70">Scan a barcode or search for products</p>
      </div>
    )
  }

  return (
    <table className="w-full text-left">
      <thead>
        <tr className="border-b border-theme text-xs text-muted">
          <th className="px-3 py-2 font-medium">Code</th>
          <th className="px-3 py-2 font-medium">Item</th>
          <th className="px-3 py-2 text-right font-medium">Price</th>
          <th className="px-3 py-2 text-center font-medium">Qty</th>
          <th className="px-3 py-2 text-right font-medium">Total</th>
          {order.status === "draft" && <th className="px-3 py-2 w-8" />}
        </tr>
      </thead>
      <tbody>
        {order.order_lines.map((line) => (
          <LineItem
            key={line.id}
            line={line}
            orderStatus={order.status}
            onReload={onReload}
          />
        ))}
      </tbody>
    </table>
  )
}
