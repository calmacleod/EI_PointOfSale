import { formatCurrency } from "../../../lib/formatCurrency"

export default function TotalsPanel({ order }) {
  return (
    <div className="border-b border-theme p-3">
      <div className="mb-1.5 text-xs font-semibold uppercase tracking-wide text-muted">Totals</div>

      <div className="space-y-1">
        <Row label="Subtotal" value={formatCurrency(order.subtotal)} />
        {order.discount_total > 0 && (
          <Row label="Discounts" value={`-${formatCurrency(order.discount_total)}`} valueClass="text-green-600" />
        )}
        {order.tax_total > 0 && (
          <Row label="Tax" value={formatCurrency(order.tax_total)} />
        )}
        <Row label="Total" value={formatCurrency(order.total)} labelClass="font-semibold text-body" valueClass="font-semibold text-body text-base" />

        {order.amount_paid > 0 && (
          <Row label="Paid" value={formatCurrency(order.amount_paid)} valueClass="text-green-600" />
        )}
        {order.amount_remaining > 0.02 && (
          <Row label="Remaining" value={formatCurrency(order.amount_remaining)} valueClass="font-semibold text-red-600" />
        )}
        {order.payment_complete && order.amount_paid > 0 && (
          <div className="mt-1 rounded bg-green-50 px-2 py-1 text-center text-xs font-medium text-green-700">
            Payment complete
          </div>
        )}
      </div>
    </div>
  )
}

function Row({ label, value, labelClass = "text-muted", valueClass = "text-body" }) {
  return (
    <div className="flex items-center justify-between">
      <span className={`text-xs ${labelClass}`}>{label}</span>
      <span className={`text-xs ${valueClass}`}>{value}</span>
    </div>
  )
}
