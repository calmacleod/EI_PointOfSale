// A small, per-screen cache: repeated lookups are immediate, and an old response
// can never replace results for the text currently in the input.
export function createLiveSearch({ url, onChange, minLength = 2, delay = 75, ttl = 30_000, fetcher = fetch }) {
  const cache = new Map()
  let timer
  let request
  let sequence = 0

  function cancel() {
    sequence += 1
    clearTimeout(timer)
    request?.abort()
    request = undefined
  }

  async function run(query, version) {
    const controller = new AbortController()
    request = controller
    try {
      const address = new URL(url, window.location.origin)
      address.searchParams.set("q", query)
      const response = await fetcher(address, { headers: { Accept: "application/json" }, signal: controller.signal })
      if (!response.ok || response.redirected) throw new Error("Search unavailable. Try again.")
      const results = (await response.json()).results || []
      if (version !== sequence) return
      cache.delete(query.toLowerCase())
      cache.set(query.toLowerCase(), { results, at: Date.now() })
      if (cache.size > 50) cache.delete(cache.keys().next().value)
      onChange({ results, loading: false, error: "", searched: true })
    } catch (error) {
      if (version === sequence && error.name !== "AbortError") onChange({ results: [], loading: false, error: "Search unavailable. Try again.", searched: true })
    } finally {
      if (request === controller) request = undefined
    }
  }

  return {
    search(value) {
      cancel()
      const query = value.trim()
      if (query.length < minLength) {
        onChange({ results: [], loading: false, error: "", searched: false })
        return
      }
      const cached = cache.get(query.toLowerCase())
      if (cached && Date.now() - cached.at < ttl) {
        onChange({ results: cached.results, loading: false, error: "", searched: true })
        return
      }
      const version = sequence
      onChange({ results: [], loading: true, error: "", searched: false })
      if (delay === 0) return run(query, version)
      timer = setTimeout(() => run(query, version), delay)
    },
    cancel,
    destroy() { cancel(); cache.clear() },
  }
}
