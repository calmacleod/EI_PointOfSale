const OK_STATES = ["complete", "completed", "success", "successful", "settled", "active", "open", "stocked", "connected", "ready"]
const WARN_STATES = ["held", "pending", "processing", "running", "low", "overdue", "warning", "outstanding"]
const BAD_STATES = ["failed", "failure", "voided", "cancelled", "canceled", "negative", "error", "inactive"]
const LIVE_STATES = ["draft", "in progress", "in_progress", "queued", "syncing", "live"]

export function stateTone(value) {
  const state = String(value || "").trim().toLowerCase()
  if (OK_STATES.some((candidate) => state.includes(candidate))) return "ok"
  if (WARN_STATES.some((candidate) => state.includes(candidate))) return "warn"
  if (BAD_STATES.some((candidate) => state.includes(candidate))) return "bad"
  if (LIVE_STATES.some((candidate) => state.includes(candidate))) return "live"
  return "idle"
}

export function rowTone(row) {
  const values = row?.values || row || {}
  const stateValue = values.status ?? values.state ?? values.last_job_status
  if (stateValue) return stateTone(stateValue)

  const stock = Number(values.stock_level ?? values.stock ?? Number.NaN)
  if (Number.isFinite(stock)) {
    if (stock < 0) return "bad"
    if (stock === 0) return "warn"
    return "ok"
  }

  if (values.active === false || String(values.active).toLowerCase() === "no") return "idle"
  return "idle"
}

export function displayValue(value) {
  if (value === null || value === undefined || value === "") return "—"
  if (typeof value === "object") return JSON.stringify(value)
  return value
}

export function machineField(key = "", label = "") {
  return /(id|code|sku|number|price|cost|amount|total|stock|quantity|qty|rate|count|date|time|_at|phone|postal)/i.test(`${key} ${label}`)
}

export function numericField(key = "", label = "") {
  return /(price|cost|amount|total|stock|quantity|qty|rate|count|variance|balance|sales)/i.test(`${key} ${label}`)
}
