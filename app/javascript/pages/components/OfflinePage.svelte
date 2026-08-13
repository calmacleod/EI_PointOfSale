<script>
  import { onMount } from "svelte"
  import RefreshCw from "@lucide/svelte/icons/refresh-cw"
  import { connectionAvailable } from "../../lib/connection.js"
  import { COLLECTIONS, DEFAULT_SYNC_PATHS, loadOfflineCatalogSummary, loadOfflineRecords, syncOfflineCatalog } from "../../lib/offline-catalog.js"
  import EmptyState from "./EmptyState.svelte"
  import PanelHeader from "./PanelHeader.svelte"
  import StatusTag from "./StatusTag.svelte"

  export let sync_paths = DEFAULT_SYNC_PATHS
  export let home_path = "/"
  export let allow_fake_offline = false

  const views = [
    { value: "products", label: "Products" },
    { value: "services", label: "Services" },
    { value: "customers", label: "Customers" },
    { value: "tax_codes", label: "Tax codes" },
  ]

  let activeView = "products"
  let query = ""
  let records = []
  let summary = emptySummary()
  let loading = true
  let catalogReady = false
  let syncing = false
  let syncError = null
  let confirmingFullSync = false
  let online = typeof navigator === "undefined" ? true : navigator.onLine
  let searchTimer
  let searchInput
  let fakeOffline = false

  $: activeConfig = COLLECTIONS[activeView]
  $: activeStatus = summary[activeView] || { count: 0, syncedAt: null }

  onMount(() => {
    let cancelled = false
    fakeOffline = readStorageValue("ei_pos_fake_offline") === "true"
    const syncConnectionState = async () => { const available = await connectionAvailable(); if (!cancelled) online = available }
    const handleCatalogUpdate = () => { if (!cancelled) loadState() }
    window.addEventListener("online", syncConnectionState)
    window.addEventListener("offline", syncConnectionState)
    window.addEventListener("ei-pos-offline-catalog", handleCatalogUpdate)
    syncConnectionState()
    const connectionTimer = window.setInterval(syncConnectionState, 3_000)
    loadState().then(async () => {
      if (cancelled) return
      loading = false
      if (await connectionAvailable()) await runSync(false)
      if (!cancelled) catalogReady = true
    }).catch(() => { if (!cancelled) { loading = false; catalogReady = true } })
    return () => {
      cancelled = true
      window.clearInterval(connectionTimer)
      if (searchTimer) window.clearTimeout(searchTimer)
      window.removeEventListener("online", syncConnectionState)
      window.removeEventListener("offline", syncConnectionState)
      window.removeEventListener("ei-pos-offline-catalog", handleCatalogUpdate)
    }
  })

  async function loadState() { summary = await loadOfflineCatalogSummary(); records = await loadOfflineRecords(activeView, query) }
  async function chooseView(view) { activeView = view; query = ""; if (searchInput) searchInput.value = ""; records = await loadOfflineRecords(activeView) }
  function queueSearch() { if (searchTimer) window.clearTimeout(searchTimer); searchTimer = window.setTimeout(async () => { records = await loadOfflineRecords(activeView, query) }, 120) }
  function handleSearch(event) { query = event.target.value; queueSearch() }
  async function runSync(full = false) {
    syncing = true
    syncError = null
    confirmingFullSync = false
    try {
      if (!(await connectionAvailable())) throw new Error("offline")
      await syncOfflineCatalog(sync_paths || DEFAULT_SYNC_PATHS, { full })
      await loadState()
    } catch (_error) {
      online = await connectionAvailable()
      syncError = online ? "Sync failed. Try again." : "You are offline. Cached data is still available."
    } finally { syncing = false }
  }
  function emptySummary() { return Object.fromEntries(Object.keys(COLLECTIONS).map((collection) => [collection, { count: 0, syncedAt: null }])) }
  function formatMoney(value) { return new Intl.NumberFormat("en-CA", { style: "currency", currency: "CAD" }).format(Number(value || 0)) }
  function formatRate(value) { return new Intl.NumberFormat("en-CA", { style: "percent", maximumFractionDigits: 3 }).format(Number(value || 0)) }
  function formatTime(value) { if (!value) return "Never synced"; return `Synced ${new Date(value).toLocaleString()}` }
  function customerAddress(customer) { return [customer.address_line1, customer.address_line2, customer.city, customer.province, customer.postal_code].filter(Boolean).join(", ") }
  function stockTone(record) { const stock = Number(record.stock_level || 0); return stock < 0 ? "bad" : stock === 0 ? "warn" : "ok" }
  function toggleFakeOffline() { window.localStorage.setItem("ei_pos_fake_offline", fakeOffline ? "false" : "true"); window.location.reload() }
  function readStorageValue(key) { try { return window.localStorage.getItem(key) } catch (_error) { return null } }
</script>

<section class="screen" data-testid="offline-catalog" data-ready={catalogReady} data-query={query}>
  <div class={`n-bar ${online ? "n-ok" : "n-warn"}`}>
    <span data-testid="offline-connection-status"><strong>{online ? "Connection restored." : "Offline lookup active."}</strong> {online ? "Sync this device or return to the live point of sale." : "Sales and changes remain unavailable until the server returns."}</span>
    <span class="n-bar-actions">
      <span data-testid="offline-connection-badge"><StatusTag value={online ? "Back online" : "Offline"} tone={online ? "ok" : "warn"} /></span>
      {#if online}<a href={home_path} class="k-btn k-btn-xs k-btn-primary" data-testid="exit-offline-mode">Return to POS</a>{/if}
      {#if allow_fake_offline}<button type="button" class="k-btn k-btn-xs" onclick={toggleFakeOffline}>{fakeOffline ? "Restore connection" : "Fake offline"}</button>{/if}
    </span>
  </div>

  <div class="m-strip" style="grid-template-columns:repeat(4,minmax(0,1fr))">
    {#each views as view}<button class="m-cell" style="text-align:left;border:0;border-left:1px solid var(--color-border);background:{activeView === view.value ? 'var(--color-accent-quiet)' : 'var(--color-surface)'}" type="button" onclick={() => chooseView(view.value)}><p class="m-label">{view.label}</p><p class="m-value">{summary[view.value]?.count || 0}</p><p class="m-note">{formatTime(summary[view.value]?.syncedAt)}</p></button>{/each}
  </div>

  {#if syncError}<div class="n-bar n-bad" role="alert">{syncError}</div>{/if}
  {#if confirmingFullSync}<div class="n-bar n-warn"><span><strong>Replace all saved lookup data?</strong> The current offline catalogue will be rebuilt from the server.</span><span class="n-bar-actions"><button class="k-btn k-btn-xs" type="button" onclick={() => (confirmingFullSync = false)}>Keep saved data</button><button class="k-btn k-btn-xs k-btn-danger-solid" type="button" disabled={syncing} onclick={() => runSync(true)}>Replace and sync</button></span></div>{/if}

  <div class="f-bar">
    <span class="p-title">Lookup</span>
    <div class="k-seg" role="tablist" aria-label="Offline lookup categories">
      {#each views as view}<button type="button" role="tab" aria-selected={activeView === view.value} data-testid={`offline-tab-${view.value}`} onclick={() => chooseView(view.value)}>{view.label} · {summary[view.value]?.count || 0}</button>{/each}
    </div>
    <span class="p-title">Filter</span>
    <input bind:this={searchInput} class="k-input k-input-sm" style="width:min(340px,42vw)" placeholder={`Search cached ${activeConfig.label.toLowerCase()}…`} oninput={handleSearch} data-testid="offline-search" />
    <button type="button" class="k-btn k-btn-sm push" disabled={syncing || !online} onclick={() => runSync(false)}><RefreshCw />{syncing ? "Syncing…" : "Sync now"}</button>
    <button type="button" class="k-btn k-btn-sm k-btn-quiet" disabled={syncing || !online} onclick={() => (confirmingFullSync = true)}>Full re-sync</button>
  </div>

  <section class="p-region" data-testid="offline-results">
    <PanelHeader title={`Cached ${activeConfig.label}`} count={`${records.length} shown · ${activeStatus.count} saved`} />
    {#if loading}
      <EmptyState title="Loading saved data" body="Reading the catalogue stored on this device." />
    {:else if activeStatus.count === 0}
      <EmptyState title={`No ${activeConfig.label.toLowerCase()} saved`} body="Reconnect and choose Sync now to prepare this device for offline lookup." />
    {:else if records.length === 0}
      <EmptyState title="No matching saved records" body={`No cached ${activeConfig.label.toLowerCase()} match “${query}”.`} />
    {:else}
      <div class="t-wrap">
        <table class="t" style="min-width:820px">
          {#if activeView === "products"}
            <thead><tr><th>Code</th><th>Product</th><th>Group / supplier</th><th>Tax</th><th class="r">Stock</th><th class="r">Price</th></tr></thead><tbody>{#each records as record (record.id)}<tr data-state={stockTone(record)}><td class="data">{record.code || "—"}</td><td class="wrap"><strong>{record.name}</strong></td><td>{record.product_group || "Uncategorized"}<span class="t-sub">{record.supplier || "—"}</span></td><td>{record.tax_code || "—"}</td><td class="r data">{record.stock_level ?? 0}</td><td class="r data">{formatMoney(record.selling_price)}</td></tr>{/each}</tbody>
          {:else if activeView === "services"}
            <thead><tr><th>Code</th><th>Service</th><th>Description</th><th>Tax</th><th class="r">Price</th></tr></thead><tbody>{#each records as record (record.id)}<tr data-state="ok"><td class="data">{record.code || "—"}</td><td><strong>{record.name}</strong></td><td class="wrap">{record.description || "—"}</td><td>{record.tax_code || "—"}</td><td class="r data">{formatMoney(record.price)}</td></tr>{/each}</tbody>
          {:else if activeView === "customers"}
            <thead><tr><th>Member</th><th>Customer</th><th>Contact</th><th>Address</th><th>Alert</th></tr></thead><tbody>{#each records as record (record.id)}<tr data-state={record.alert ? "warn" : "idle"}><td class="data">{record.member_number || "—"}</td><td><strong>{record.name}</strong></td><td>{[record.email, record.phone].filter(Boolean).join(" · ") || "—"}</td><td class="wrap">{customerAddress(record) || "—"}</td><td class="wrap">{record.alert || "—"}</td></tr>{/each}</tbody>
          {:else}
            <thead><tr><th>Code</th><th>Tax code</th><th>Province</th><th>Exemption</th><th class="r">Rate</th></tr></thead><tbody>{#each records as record (record.id)}<tr data-state="idle"><td class="data">{record.code}</td><td><strong>{record.name}</strong></td><td class="data">{record.province_code || "—"}</td><td>{record.exemption_type || "—"}</td><td class="r data">{formatRate(record.rate)}</td></tr>{/each}</tbody>
          {/if}
        </table>
      </div>
    {/if}
  </section>
</section>
