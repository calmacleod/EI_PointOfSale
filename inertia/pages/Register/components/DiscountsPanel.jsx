import { formatCurrency } from "../../../lib/formatCurrency"

export default function DiscountsPanel({ order, onRemoveDiscount }) {
  const { order_discounts, order_lines } = order
  const isDraft = order.status === "draft"

  // Gather auto line discounts for summary display
  const lineDiscountNames = {}
  for (const line of order_lines) {
    for (const d of line.line_discounts) {
      if (!lineDiscountNames[d.name]) lineDiscountNames[d.name] = 0
      lineDiscountNames[d.name] += d.calculated_amount
    }
  }

  const hasDiscounts = order_discounts.length > 0 || Object.keys(lineDiscountNames).length > 0
  if (!hasDiscounts) return null

  return (
    <div className="border-b border-theme p-3">
      <div className="mb-1.5 text-xs font-semibold uppercase tracking-wide text-muted">Discounts</div>

      {order_discounts.map((d) => (
        <div key={d.id} className="flex items-center justify-between py-0.5">
          <div>
            <span className="text-xs text-body">{d.name}</span>
            {d.auto_applied && (
              <span className="ml-1 rounded bg-blue-100 px-1 text-[10px] text-blue-700">auto</span>
            )}
            <span className="ml-1 text-[10px] text-muted">({d.display_value})</span>
          </div>
          <div className="flex items-center gap-1.5">
            <span className="text-xs text-green-600">-{formatCurrency(d.calculated_amount)}</span>
            {isDraft && !d.auto_applied && (
              <button
                type="button"
                onClick={() => onRemoveDiscount(d.delete_url + ".json")}
                className="rounded p-0.5 text-muted hover:text-red-600"
                aria-label="Remove discount"
              >
                <svg className="h-3 w-3" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M6 18L18 6M6 6l12 12" />
                </svg>
              </button>
            )}
          </div>
        </div>
      ))}

      {Object.entries(lineDiscountNames).map(([name, amount]) => (
        <div key={name} className="flex items-center justify-between py-0.5">
          <div>
            <span className="text-xs text-body">{name}</span>
            <span className="ml-1 rounded bg-blue-100 px-1 text-[10px] text-blue-700">auto · per item</span>
          </div>
          <span className="text-xs text-green-600">-{formatCurrency(amount)}</span>
        </div>
      ))}
    </div>
  )
}
