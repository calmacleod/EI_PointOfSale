import { useState } from "react"
import { formatCurrency } from "../../../lib/formatCurrency"
import { csrfToken } from "../../../lib/csrf"

export default function LineItem({ line, orderStatus, onReload }) {
  const [editing, setEditing] = useState(false)
  const [qty, setQty] = useState(line.quantity)
  const isDraft = orderStatus === "draft"

  function startEdit() {
    if (!isDraft) return
    setQty(line.quantity)
    setEditing(true)
  }

  async function saveQty() {
    setEditing(false)
    const newQty = parseInt(qty, 10)
    if (isNaN(newQty) || newQty < 1 || newQty === line.quantity) return

    await fetch(line.update_url + ".json", {
      method: "PATCH",
      headers: { "X-CSRF-Token": csrfToken(), "Content-Type": "application/json", Accept: "application/json" },
      body: JSON.stringify({ order_line: { quantity: newQty } }),
    })
    onReload()
  }

  async function deleteLine() {
    await fetch(line.delete_url + ".json", {
      method: "DELETE",
      headers: { "X-CSRF-Token": csrfToken(), Accept: "application/json" },
    })
    onReload()
  }

  return (
    <tr className="group border-b border-theme hover:bg-page/50">
      <td className="px-3 py-2 text-xs text-muted font-mono">{line.code}</td>
      <td className="px-3 py-2">
        <div className="text-sm font-medium text-body">{line.name}</div>
        {line.line_discounts.length > 0 && (
          <div className="mt-0.5 flex flex-wrap gap-1">
            {line.line_discounts.map((d) => (
              <span key={d.id} className="rounded bg-green-100 px-1 text-[10px] text-green-700">
                -{formatCurrency(d.calculated_amount)} {d.name}
              </span>
            ))}
          </div>
        )}
        {line.tax_rate > 0 && (
          <div className="mt-0.5 text-[10px] text-muted">
            {(line.tax_rate * 100).toFixed(0)}% tax · {formatCurrency(line.tax_amount)}
          </div>
        )}
      </td>
      <td className="px-3 py-2 text-right text-xs text-muted">{formatCurrency(line.unit_price)}</td>
      <td className="px-3 py-2 text-center">
        {editing ? (
          <input
            type="number"
            className="w-12 rounded border border-accent px-1 py-0.5 text-center text-sm focus:outline-none"
            value={qty}
            min={1}
            autoFocus
            onChange={(e) => setQty(e.target.value)}
            onBlur={saveQty}
            onKeyDown={(e) => {
              if (e.key === "Enter") saveQty()
              if (e.key === "Escape") setEditing(false)
            }}
          />
        ) : (
          <button
            type="button"
            onClick={startEdit}
            className={`min-w-[2rem] rounded px-1.5 py-0.5 text-sm ${isDraft ? "cursor-pointer hover:bg-(--color-border)" : "cursor-default"}`}
          >
            {line.quantity}
          </button>
        )}
      </td>
      <td className="px-3 py-2 text-right text-sm font-medium text-body">{formatCurrency(line.line_total)}</td>
      {isDraft && (
        <td className="px-3 py-2 text-center">
          <button
            type="button"
            onClick={deleteLine}
            className="invisible rounded p-0.5 text-muted hover:bg-red-50 hover:text-red-600 group-hover:visible"
            aria-label="Remove line"
          >
            <svg className="h-3.5 w-3.5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M6 18L18 6M6 6l12 12" />
            </svg>
          </button>
        </td>
      )}
    </tr>
  )
}
