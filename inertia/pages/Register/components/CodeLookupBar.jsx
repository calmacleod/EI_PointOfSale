import { useState, useRef, useEffect } from "react"
import { csrfToken } from "../../../lib/csrf"

export default function CodeLookupBar({ order, routes, onReload, onOpenProductSearch }) {
  const [code, setCode] = useState("")
  const [flash, setFlash] = useState(null)
  const inputRef = useRef(null)

  useEffect(() => {
    inputRef.current?.focus()
  }, [])

  async function handleSubmit(e) {
    e.preventDefault()
    const trimmed = code.trim()
    if (!trimmed) return

    const resp = await fetch(routes.quick_lookup + ".json", {
      method: "POST",
      headers: { "X-CSRF-Token": csrfToken(), "Content-Type": "application/json", Accept: "application/json" },
      body: JSON.stringify({ code: trimmed, order_id: order.id }),
    })

    const data = await resp.json()
    setCode("")
    setFlash({ message: data.message, success: data.success })
    setTimeout(() => setFlash(null), 3000)

    if (data.success) onReload()
  }

  return (
    <div className="shrink-0 border-t border-theme bg-surface px-3 py-2">
      {flash && (
        <div className={`mb-1.5 rounded px-2 py-1 text-xs ${flash.success ? "bg-green-50 text-green-700" : "bg-amber-50 text-amber-700"}`}>
          {flash.message}
        </div>
      )}
      <form onSubmit={handleSubmit} className="flex items-center gap-2">
        <input
          ref={inputRef}
          type="text"
          value={code}
          onChange={(e) => setCode(e.target.value)}
          onKeyDown={(e) => { if (e.key === "Escape") setCode("") }}
          placeholder="Scan or type a code..."
          className="flex-1 rounded border border-theme bg-page px-3 py-1.5 text-sm focus:border-accent focus:outline-none"
          autoComplete="off"
          autoFocus
        />
        <button
          type="button"
          onClick={onOpenProductSearch}
          className="rounded border border-theme px-2 py-1.5 text-xs text-muted hover:bg-(--color-border)"
          title="Search products"
        >
          <svg className="h-4 w-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z" />
          </svg>
        </button>
      </form>
    </div>
  )
}
