import { useState, useEffect, useRef } from "react"
import { csrfToken } from "../../../lib/csrf"
import { formatCurrency } from "../../../lib/formatCurrency"

export default function ProductSearchModal({ order, routes, onClose, onAdded }) {
  const [query, setQuery] = useState("")
  const [results, setResults] = useState([])
  const [selected, setSelected] = useState(null)
  const [filter, setFilter] = useState("all")
  const [adding, setAdding] = useState(false)
  const inputRef = useRef(null)

  useEffect(() => { inputRef.current?.focus() }, [])

  useEffect(() => {
    if (!query.trim()) { setResults([]); return }

    const timeout = setTimeout(async () => {
      const params = new URLSearchParams({ q: query, limit: 20 })
      if (filter !== "all") params.set("type", filter === "products" ? "Product" : "Service")
      const resp = await fetch(`${routes.product_search}.json?${params}`, {
        headers: { Accept: "application/json" },
      })
      const data = await resp.json()
      setResults(data.results ?? [])
    }, 150)

    return () => clearTimeout(timeout)
  }, [query, filter])

  async function addItem(item) {
    setAdding(true)
    const resp = await fetch(routes.order_lines + ".json", {
      method: "POST",
      headers: { "X-CSRF-Token": csrfToken(), "Content-Type": "application/json", Accept: "application/json" },
      body: JSON.stringify({ sellable_type: item.type, sellable_id: item.id, quantity: 1 }),
    })
    setAdding(false)
    if (resp.ok) onAdded()
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
      addItem(selected)
    }
  }

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/40" onClick={(e) => e.target === e.currentTarget && onClose()}>
      <div className="flex h-[80vh] w-full max-w-2xl flex-col rounded-xl border border-theme bg-surface shadow-xl overflow-hidden">
        <div className="flex items-center gap-3 border-b border-theme px-4 py-3">
          <svg className="h-4 w-4 shrink-0 text-muted" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z" />
          </svg>
          <input
            ref={inputRef}
            type="text"
            value={query}
            onChange={(e) => { setQuery(e.target.value); setSelected(null) }}
            onKeyDown={handleKeyDown}
            placeholder="Search products and services..."
            className="flex-1 bg-transparent text-sm focus:outline-none text-body placeholder-muted"
          />
          <button type="button" onClick={onClose} className="text-muted hover:text-body">
            <svg className="h-4 w-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M6 18L18 6M6 6l12 12" />
            </svg>
          </button>
        </div>

        <div className="flex gap-2 border-b border-theme px-4 py-2">
          {["all", "products", "services"].map((f) => (
            <button
              key={f}
              type="button"
              onClick={() => setFilter(f)}
              className={`rounded px-2 py-0.5 text-xs capitalize ${filter === f ? "bg-accent text-white" : "text-muted hover:bg-(--color-border)"}`}
            >
              {f}
            </button>
          ))}
        </div>

        <div className="flex min-h-0 flex-1">
          {/* Results */}
          <div className="w-1/2 overflow-y-auto border-r border-theme">
            {results.length === 0 && query.trim() && (
              <div className="p-4 text-center text-sm text-muted">No results</div>
            )}
            {results.length === 0 && !query.trim() && (
              <div className="p-4 text-center text-sm text-muted">Type to search</div>
            )}
            {results.map((item, i) => (
              <button
                key={item.id ?? i}
                type="button"
                onClick={() => setSelected(item)}
                onDoubleClick={() => addItem(item)}
                className={`w-full px-3 py-2 text-left text-sm transition-colors hover:bg-page/50 ${selected === item ? "bg-accent/10" : ""}`}
              >
                <div className="font-medium text-body truncate">{item.label}</div>
                {item.sublabel && <div className="text-xs text-muted truncate">{item.sublabel}</div>}
              </button>
            ))}
          </div>

          {/* Preview */}
          <div className="w-1/2 overflow-y-auto p-4">
            {selected ? (
              <div className="space-y-3">
                <div>
                  <div className="text-sm font-semibold text-body">{selected.label}</div>
                  {selected.sublabel && <div className="text-xs text-muted">{selected.sublabel}</div>}
                </div>
                <div className="text-xs text-muted capitalize">{selected.type?.toLowerCase()}</div>
                <button
                  type="button"
                  disabled={adding}
                  onClick={() => addItem(selected)}
                  className="w-full rounded bg-accent px-3 py-2 text-sm font-medium text-white hover:bg-accent/90 disabled:opacity-50"
                >
                  {adding ? "Adding..." : "Add to Order"}
                </button>
              </div>
            ) : (
              <div className="flex h-full items-center justify-center text-xs text-muted">
                Select an item to add
              </div>
            )}
          </div>
        </div>
      </div>
    </div>
  )
}
