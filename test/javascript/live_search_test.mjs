import assert from "node:assert/strict"
import { test } from "node:test"
import { createLiveSearch } from "../../app/javascript/lib/live-search.js"

globalThis.window = { location: { origin: "http://localhost" } }
const response = (results) => ({ ok: true, json: async () => ({ results }) })

test("a late response cannot overwrite a newer query even if abort is ignored", async () => {
  const requests = []
  const states = []
  const lookup = createLiveSearch({ url: "/search", delay: 0, onChange: (state) => states.push(state), fetcher: (url, options) => new Promise((resolve) => requests.push({ url, options, resolve })) })
  const oldSearch = lookup.search("Dragon")
  const newSearch = lookup.search("Puck")
  assert.equal(requests[0].options.signal.aborted, true)
  requests[1].resolve(response(["Puck"]))
  await newSearch
  requests[0].resolve(response(["Dragon"]))
  await oldSearch
  assert.deepEqual(states.at(-1).results, ["Puck"])
  lookup.destroy()
})

test("clearing or destroying a search invalidates in-flight responses", async () => {
  for (const action of ["clear", "destroy"]) {
    let finish
    const states = []
    const lookup = createLiveSearch({ url: "/search", delay: 0, onChange: (state) => states.push(state), fetcher: () => new Promise((resolve) => (finish = resolve)) })
    const pending = lookup.search("Dragon")
    if (action === "clear") lookup.search("")
    else lookup.destroy()
    const stateCount = states.length
    finish(response(["stale"]))
    await pending
    assert.equal(states.length, stateCount)
  }
})

test("repeat lookups use a bounded memory cache and expired results are refreshed", async () => {
  let requests = 0
  let state
  const lookup = createLiveSearch({ url: "/search", delay: 0, ttl: 30_000, onChange: (value) => (state = value), fetcher: async () => { requests++; return response([requests]) } })
  await lookup.search("Dragon")
  lookup.search(" dragon ")
  assert.equal(requests, 1)
  assert.deepEqual(state.results, [1])
  for (let i = 0; i < 51; i++) await lookup.search(`other-${i}`)
  await lookup.search("Dragon")
  assert.equal(requests, 53)
  lookup.destroy()
  const uncached = createLiveSearch({ url: "/search", delay: 0, ttl: 0, onChange: () => {}, fetcher: async () => { requests++; return response([]) } })
  await uncached.search("same")
  await uncached.search("same")
  assert.equal(requests, 55)
  uncached.destroy()
})

test("failed or redirected responses show an error and are never cached", async () => {
  let state
  let requests = 0
  const lookup = createLiveSearch({ url: "/search", delay: 0, onChange: (value) => (state = value), fetcher: async () => { requests++; return { ok: true, redirected: true } } })
  await lookup.search("Dragon")
  assert.ok(state.error)
  assert.equal(state.loading, false)
  await lookup.search("Dragon")
  assert.equal(requests, 2)
  lookup.destroy()
})
