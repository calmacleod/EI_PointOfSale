import { formatCurrency } from "../../../lib/formatCurrency"

const METHOD_LABELS = {
  cash: "Cash",
  debit: "Debit",
  credit: "Credit",
  store_credit: "Store Credit",
  gift_certificate: "Gift Cert",
  other: "Other",
}

export default function PaymentsPanel({ order, onAddPayment, onRemovePayment }) {
  const isDraft = order.status === "draft"

  return (
    <div className="border-b border-theme p-3">
      <div className="mb-1.5 flex items-center justify-between">
        <span className="text-xs font-semibold uppercase tracking-wide text-muted">Payments</span>
        {isDraft && (
          <button
            type="button"
            onClick={onAddPayment}
            className="rounded px-1.5 py-0.5 text-xs text-accent hover:bg-accent/10"
          >
            + Add
          </button>
        )}
      </div>

      {order.order_payments.length === 0 ? (
        <div className="text-xs text-muted">No payments yet</div>
      ) : (
        <div className="space-y-1">
          {order.order_payments.map((payment) => (
            <div key={payment.id} className="flex items-center justify-between">
              <div>
                <span className="text-xs font-medium text-body">{METHOD_LABELS[payment.payment_method] ?? payment.display_method}</span>
                {payment.payment_method === "cash" && payment.amount_tendered && (
                  <span className="ml-1 text-[10px] text-muted">
                    (tendered {formatCurrency(payment.amount_tendered)}, change {formatCurrency(payment.change_given)})
                  </span>
                )}
                {payment.reference && payment.payment_method !== "cash" && (
                  <span className="ml-1 text-[10px] text-muted">{payment.reference}</span>
                )}
              </div>
              <div className="flex items-center gap-1.5">
                <span className="text-xs text-body">{formatCurrency(payment.amount)}</span>
                {isDraft && (
                  <button
                    type="button"
                    onClick={() => onRemovePayment(payment.delete_url + ".json")}
                    className="rounded p-0.5 text-muted hover:text-red-600"
                    aria-label="Remove payment"
                  >
                    <svg className="h-3 w-3" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M6 18L18 6M6 6l12 12" />
                    </svg>
                  </button>
                )}
              </div>
            </div>
          ))}
        </div>
      )}
    </div>
  )
}
