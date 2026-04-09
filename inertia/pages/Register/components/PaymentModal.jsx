import { useState, useEffect } from "react"
import { formatCurrency } from "../../../lib/formatCurrency"
import { csrfToken } from "../../../lib/csrf"

const METHODS = [
  { value: "cash", label: "Cash" },
  { value: "debit", label: "Debit" },
  { value: "credit", label: "Credit" },
  { value: "store_credit", label: "Store Credit" },
  { value: "gift_certificate", label: "Gift Cert" },
  { value: "other", label: "Other" },
]

// Round to nearest $0.05 (Canadian cash rounding)
function roundToNickel(amount) {
  return Math.round(amount * 20) / 20
}

export default function PaymentModal({ order, routes, onClose, onSuccess }) {
  const [method, setMethod] = useState("cash")
  const [amount, setAmount] = useState(order.amount_remaining.toFixed(2))
  const [tendered, setTendered] = useState("")
  const [reference, setReference] = useState("")
  const [gcBalance, setGcBalance] = useState(null)
  const [gcNotFound, setGcNotFound] = useState(false)
  const [error, setError] = useState(null)
  const [submitting, setSubmitting] = useState(false)

  const isCash = method === "cash"
  const isGC = method === "gift_certificate"
  const remaining = order.amount_remaining

  const tenderedNum = parseFloat(tendered) || 0
  const amountNum = parseFloat(amount) || 0
  const change = isCash ? Math.max(0, tenderedNum - amountNum) : 0
  const roundedAmount = isCash ? roundToNickel(amountNum) : amountNum

  useEffect(() => {
    if (!isGC || !reference.trim()) {
      setGcBalance(null)
      setGcNotFound(false)
      return
    }

    const timeout = setTimeout(async () => {
      const resp = await fetch(`${routes.gift_certificate_lookup}?code=${encodeURIComponent(reference.trim())}`, {
        headers: { Accept: "application/json" },
      })
      const data = await resp.json()
      if (data.found) {
        setGcBalance(data.balance)
        setGcNotFound(false)
        setAmount(Math.min(data.balance, remaining).toFixed(2))
      } else {
        setGcBalance(null)
        setGcNotFound(true)
      }
    }, 400)

    return () => clearTimeout(timeout)
  }, [reference, isGC])

  async function handleSubmit(e) {
    e.preventDefault()
    setError(null)
    setSubmitting(true)

    const body = {
      order_payment: {
        payment_method: method,
        amount: roundedAmount,
        reference,
      },
    }

    if (isCash) {
      body.order_payment.amount_tendered = tenderedNum || roundedAmount
      body.order_payment.change_given = change
    }

    const resp = await fetch(routes.order_payments + ".json", {
      method: "POST",
      headers: { "X-CSRF-Token": csrfToken(), "Content-Type": "application/json", Accept: "application/json" },
      body: JSON.stringify(body),
    })

    const data = await resp.json()
    setSubmitting(false)

    if (data.success) {
      onSuccess()
    } else {
      setError(data.error || "Payment failed")
    }
  }

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/40" onClick={(e) => e.target === e.currentTarget && onClose()}>
      <div className="w-full max-w-sm rounded-xl border border-theme bg-surface shadow-xl">
        <div className="flex items-center justify-between border-b border-theme px-4 py-3">
          <h2 className="text-sm font-semibold text-body">Add Payment</h2>
          <button type="button" onClick={onClose} className="text-muted hover:text-body">
            <svg className="h-4 w-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M6 18L18 6M6 6l12 12" />
            </svg>
          </button>
        </div>

        <form onSubmit={handleSubmit} className="p-4 space-y-3">
          {/* Method buttons */}
          <div className="grid grid-cols-3 gap-1.5">
            {METHODS.map((m) => (
              <button
                key={m.value}
                type="button"
                onClick={() => { setMethod(m.value); setReference(""); setGcBalance(null); setGcNotFound(false) }}
                className={`rounded px-2 py-1.5 text-xs font-medium transition-colors ${
                  method === m.value ? "bg-accent text-white" : "border border-theme text-body hover:bg-(--color-border)"
                }`}
              >
                {m.label}
              </button>
            ))}
          </div>

          {/* Amount */}
          <div>
            <label className="mb-1 block text-xs text-muted">Amount</label>
            <input
              type="number"
              step="0.01"
              min="0.01"
              value={amount}
              onChange={(e) => setAmount(e.target.value)}
              className="w-full rounded border border-theme bg-page px-3 py-1.5 text-sm focus:border-accent focus:outline-none"
              required
            />
          </div>

          {/* Cash section */}
          {isCash && (
            <div className="rounded border border-theme p-3 space-y-2">
              <div>
                <label className="mb-1 block text-xs text-muted">Tendered</label>
                <input
                  type="number"
                  step="0.05"
                  min={amountNum}
                  value={tendered}
                  onChange={(e) => setTendered(e.target.value)}
                  placeholder={roundedAmount.toFixed(2)}
                  className="w-full rounded border border-theme bg-page px-3 py-1.5 text-sm focus:border-accent focus:outline-none"
                />
              </div>
              {tenderedNum > 0 && (
                <div className="flex items-center justify-between text-sm">
                  <span className="text-muted">Change</span>
                  <span className="font-semibold text-body">{formatCurrency(change)}</span>
                </div>
              )}
            </div>
          )}

          {/* Reference / GC section */}
          {(isGC || method === "debit" || method === "credit" || method === "other") && (
            <div>
              <label className="mb-1 block text-xs text-muted">
                {isGC ? "Gift Certificate Code" : "Reference (optional)"}
              </label>
              <input
                type="text"
                value={reference}
                onChange={(e) => setReference(e.target.value)}
                placeholder={isGC ? "Enter GC code..." : "Transaction reference..."}
                className="w-full rounded border border-theme bg-page px-3 py-1.5 text-sm focus:border-accent focus:outline-none"
                required={isGC}
              />
              {isGC && gcBalance !== null && (
                <div className="mt-1 text-xs text-green-600">Balance: {formatCurrency(gcBalance)}</div>
              )}
              {isGC && gcNotFound && (
                <div className="mt-1 text-xs text-red-600">Gift certificate not found or not active</div>
              )}
            </div>
          )}

          {error && (
            <div className="rounded bg-red-50 px-3 py-2 text-xs text-red-700">{error}</div>
          )}

          <div className="flex gap-2 pt-1">
            <button
              type="button"
              onClick={onClose}
              className="flex-1 rounded border border-theme px-3 py-1.5 text-sm text-body hover:bg-(--color-border)"
            >
              Cancel
            </button>
            <button
              type="submit"
              disabled={submitting || (isGC && gcNotFound)}
              className="flex-1 rounded bg-accent px-3 py-1.5 text-sm font-medium text-white hover:bg-accent/90 disabled:opacity-50"
            >
              {submitting ? "Saving..." : `Pay ${formatCurrency(roundedAmount)}`}
            </button>
          </div>
        </form>
      </div>
    </div>
  )
}
