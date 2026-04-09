import { useState, useEffect, useRef } from "react"
import { csrfToken } from "../../../lib/csrf"

export default function CustomerSearchModal({ order, routes, onClose, onAssigned }) {
  const [query, setQuery] = useState("")
  const [results, setResults] = useState([])
  const [selected, setSelected] = useState(null)
  const [assigning, setAssigning] = useState(false)
  const inputRef = useRef(null)

  useEffect(() => { inputRef.current?.focus() }, [])

  useEffect(() => {
    if (!query.trim()) { setResults([]); return }

    const timeout = setTimeout(async () => {
      const resp = await fetch(`${routes.customer_search}.json?q=${encodeURIComponent(query)}`, {
        headers: { Accept: "application/json" },
      })
      const data = await resp.json()
      setResults(data.customers ?? data.results ?? [])
    }, 200)

    return () => clearTimeout(timeout)
  }, [query])

  async function assignCustomer(customer) {
    setAssigning(true)
    await fetch(`${routes.assign_customer}.json?customer_id=${customer.id}`, {
      method: "PATCH",
      headers: { "X-CSRF-Token": csrfToken(), Accept: "application/json" },
    })
    setAssigning(false)
    onAssigned()
  }

  function handleKeyDown(e) {
    if (e.key === "Escape") onClose()
    if (e.key === "ArrowDown") {
      e.preventDefault()
      const idx = results.indexOf(selected)
      setSelected(results[Math.min(idx + 1, results.length - 1)])
    }
    if (e.key === "ArrowUp") {
      e.preventDefault()
      const idx = results.indexOf(selected)
      setSelected(results[Math.max(idx - 1, 0)])
    }
    if (e.key === "Enter" && selected) {
      assignCustomer(selected)
    }
  }

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/40" onClick={(e) => e.target === e.currentTarget && onClose()}>
      <div className="flex h-[60vh] w-full max-w-md flex-col rounded-xl border border-theme bg-surface shadow-xl overflow-hidden">
        <div className="flex items-center gap-3 border-b border-theme px-4 py-3">
          <svg className="h-4 w-4 shrink-0 text-muted" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M16 7a4 4 0 11-8 0 4 4 0 018 0zM12 14a7 7 0 00-7 7h14a7 7 0 00-7-7z" />
          </svg>
          <input
            ref={inputRef}
            type="text"
            value={query}
            onChange={(e) => { setQuery(e.target.value); setSelected(null) }}
            onKeyDown={handleKeyDown}
            placeholder="Search customers..."
            className="flex-1 bg-transparent text-sm focus:outline-none text-body placeholder-muted"
          />
          <button type="button" onClick={onClose} className="text-muted hover:text-body">
            <svg className="h-4 w-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M6 18L18 6M6 6l12 12" />
            </svg>
          </button>
        </div>

        <div className="min-h-0 flex-1 overflow-y-auto">
          {results.length === 0 && query.trim() && (
            <div className="p-4 text-center text-sm text-muted">No customers found</div>
          )}
          {results.length === 0 && !query.trim() && (
            <div className="p-4 text-center text-sm text-muted">Type to search customers</div>
          )}
          {results.map((customer, i) => (
            <button
              key={customer.id ?? i}
              type="button"
              disabled={assigning}
              onClick={() => assignCustomer(customer)}
              className={`w-full px-4 py-2.5 text-left transition-colors hover:bg-page/50 ${selected === customer ? "bg-accent/10" : ""}`}
            >
              <div className="text-sm font-medium text-body">{customer.name}</div>
              <div className="text-xs text-muted">
                {customer.member_number && `Member #${customer.member_number} · `}
                {customer.email}
              </div>
            </button>
          ))}
        </div>
      </div>
    </div>
  )
}
