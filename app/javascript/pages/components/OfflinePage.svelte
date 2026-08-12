<script>
  import { onMount } from "svelte"
  import Boxes from "@lucide/svelte/icons/boxes"
  import CloudDownload from "@lucide/svelte/icons/cloud-download"
  import RefreshCw from "@lucide/svelte/icons/refresh-cw"
  import Search from "@lucide/svelte/icons/search"
  import Tags from "@lucide/svelte/icons/tags"
  import Users from "@lucide/svelte/icons/users"
  import Wifi from "@lucide/svelte/icons/wifi"
  import WifiOff from "@lucide/svelte/icons/wifi-off"
  import Wrench from "@lucide/svelte/icons/wrench"
  import { connectionAvailable } from "../../lib/connection.js"
  import {
    COLLECTIONS,
    DEFAULT_SYNC_PATHS,
    loadOfflineCatalogSummary,
    loadOfflineRecords,
    syncOfflineCatalog,
  } from "../../lib/offline-catalog.js"

  export let sync_paths = DEFAULT_SYNC_PATHS
  export let home_path = "/"
  export let allow_fake_offline = false

  const views = [
    { value: "products", label: "Products", icon: Boxes },
    { value: "services", label: "Services", icon: Wrench },
    { value: "customers", label: "Customers", icon: Users },
    { value: "tax_codes", label: "Tax codes", icon: Tags },
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

    const syncConnectionState = async () => {
      const available = await connectionAvailable()
      if (!cancelled) online = available
    }

    const handleCatalogUpdate = () => {
      if (!cancelled) loadState()
    }

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
    }).catch(() => {
      if (!cancelled) {
        loading = false
        catalogReady = true
      }
    })

    return () => {
      cancelled = true
      window.clearInterval(connectionTimer)
      if (searchTimer) window.clearTimeout(searchTimer)
      window.removeEventListener("online", syncConnectionState)
      window.removeEventListener("offline", syncConnectionState)
      window.removeEventListener("ei-pos-offline-catalog", handleCatalogUpdate)
    }
  })

  async function loadState() {
    summary = await loadOfflineCatalogSummary()
    records = await loadOfflineRecords(activeView, query)
  }

  async function chooseView(view) {
    activeView = view
    query = ""
    if (searchInput) searchInput.value = ""
    records = await loadOfflineRecords(activeView)
  }

  function queueSearch() {
    if (searchTimer) window.clearTimeout(searchTimer)
    searchTimer = window.setTimeout(async () => {
      records = await loadOfflineRecords(activeView, query)
    }, 120)
  }

  function handleSearch(event) {
    query = event.target.value
    queueSearch()
  }

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
    } finally {
      syncing = false
    }
  }

  function emptySummary() {
    return Object.fromEntries(Object.keys(COLLECTIONS).map((collection) => [collection, { count: 0, syncedAt: null }]))
  }

  function formatMoney(value) {
    return new Intl.NumberFormat("en-CA", { style: "currency", currency: "CAD" }).format(Number(value || 0))
  }

  function formatRate(value) {
    return new Intl.NumberFormat("en-CA", { style: "percent", maximumFractionDigits: 3 }).format(Number(value || 0))
  }

  function formatTime(value) {
    if (!value) return "Never synced"
    return `Synced ${new Date(value).toLocaleString()}`
  }

  function customerAddress(customer) {
    return [customer.address_line1, customer.address_line2, customer.city, customer.province, customer.postal_code]
      .filter(Boolean)
      .join(", ")
  }

  function toggleFakeOffline() {
    const nextValue = !fakeOffline
    window.localStorage.setItem("ei_pos_fake_offline", nextValue ? "true" : "false")
    window.location.reload()
  }

  function readStorageValue(key) {
    try {
      return window.localStorage.getItem(key)
    } catch (_error) {
      return null
    }
  }
</script>

<section class="mb-6 flex flex-col gap-4 lg:flex-row lg:items-end lg:justify-between" data-testid="offline-catalog" data-ready={catalogReady} data-query={query}>
  <div>
    <p class="text-xs font-semibold uppercase tracking-wider" style="color:var(--primary)">Offline mode</p>
    <h1 class="mt-1 text-3xl font-semibold tracking-tight">Cached lookup</h1>
    <p class="mt-2 max-w-2xl text-sm" style="color:var(--muted)">
      Search the product, service, customer, and tax-code copy saved on this device. Sales and other changes stay unavailable until the connection returns.
    </p>
  </div>
  <div class="flex flex-col gap-2 lg:items-end">
    <div class="flex flex-wrap items-center gap-2">
      <span class="ui-badge flex h-7 items-center gap-1.5" data-testid="offline-connection-badge">
        {#if online}<Wifi class="size-3.5" />Back online{:else}<WifiOff class="size-3.5" />Offline{/if}
      </span>
      <span class="ui-badge h-7">Lookup only</span>
      {#if online}
        <a href={home_path} class="ui-button ui-button-primary min-h-8! px-3! text-xs" data-testid="exit-offline-mode">Return to POS</a>
      {/if}
      {#if allow_fake_offline}
        <button type="button" class="ui-button ui-button-secondary min-h-8! px-3! text-xs" onclick={toggleFakeOffline}>{fakeOffline ? "Restore connection" : "Fake offline"}</button>
      {/if}
    </div>
    <p class="max-w-md text-sm lg:text-right" style="color:var(--muted)" data-testid="offline-connection-status">
      {#if online}Connection restored. Sync the device or return to the live app.{:else}Waiting for the server before enabling live point-of-sale features.{/if}
    </p>
  </div>
</section>

<section class="ui-card mb-4 p-4">
  <div class="flex flex-col gap-3 xl:flex-row xl:items-center xl:justify-between">
    <div class="flex items-center gap-2">
      <span class="flex size-9 items-center justify-center rounded-lg" style="background:var(--accent);color:var(--primary)"><CloudDownload class="size-4" /></span>
      <div>
        <p class="text-sm font-semibold">{activeStatus.count} {activeConfig.label.toLowerCase()} saved</p>
        <p class="text-xs" style="color:var(--muted)">{formatTime(activeStatus.syncedAt)}</p>
      </div>
    </div>
    <div class="flex flex-wrap items-center gap-2">
      {#if syncError}<p class="mr-2 text-xs font-medium text-red-700" role="alert">{syncError}</p>{/if}
      <button type="button" class="ui-button ui-button-secondary min-h-8! px-3! text-xs" disabled={syncing || !online} onclick={() => runSync(false)}>
        <RefreshCw class={`size-3.5 ${syncing ? "animate-spin" : ""}`} />{syncing ? "Syncing..." : "Sync now"}
      </button>
      {#if confirmingFullSync}
        <span class="text-xs" style="color:var(--muted)">Replace all saved data?</span>
        <button type="button" class="ui-button min-h-8! border-red-300! bg-red-50! px-3! text-xs text-red-800!" disabled={syncing} onclick={() => runSync(true)}>Replace</button>
        <button type="button" class="ui-button ui-button-secondary min-h-8! px-3! text-xs" onclick={() => (confirmingFullSync = false)}>Cancel</button>
      {:else}
        <button type="button" class="ui-button ui-button-secondary min-h-8! px-3! text-xs" disabled={syncing || !online} onclick={() => (confirmingFullSync = true)}>Full re-sync</button>
      {/if}
    </div>
  </div>
</section>

<div class="mb-4 flex gap-2 overflow-x-auto pb-1" role="tablist" aria-label="Offline lookup categories">
  {#each views as view}
    <button
      type="button"
      role="tab"
      aria-selected={activeView === view.value}
      data-testid={`offline-tab-${view.value}`}
      class={`ui-button min-h-9! shrink-0 px-3! text-xs ${activeView === view.value ? "ui-button-primary" : "ui-button-secondary"}`}
      onclick={() => chooseView(view.value)}
    >
      <svelte:component this={view.icon} class="size-4" />
      {view.label}
      <span class="rounded-full bg-black/8 px-1.5 py-0.5 text-[10px]">{summary[view.value]?.count || 0}</span>
    </button>
  {/each}
</div>

<label class="relative mb-4 block">
  <span class="sr-only">Search cached {activeConfig.label.toLowerCase()}</span>
  <Search class="pointer-events-none absolute left-3 top-1/2 size-4 -translate-y-1/2" style="color:var(--muted)" />
  <input
    class="ui-input w-full pl-10! sm:max-w-xl"
    placeholder={`Search cached ${activeConfig.label.toLowerCase()}`}
    bind:this={searchInput}
    oninput={handleSearch}
    data-testid="offline-search"
  />
</label>

{#if loading}
  <div class="ui-card p-6"><p class="text-sm" style="color:var(--muted)">Loading saved data...</p></div>
{:else if activeStatus.count === 0}
  <div class="ui-card p-6">
    <p class="text-sm font-semibold">No {activeConfig.label.toLowerCase()} are saved on this device.</p>
    <p class="mt-1 text-sm" style="color:var(--muted)">Reconnect and choose Sync now to prepare this lookup for offline use.</p>
  </div>
{:else if records.length === 0}
  <div class="ui-card p-6"><p class="text-sm" style="color:var(--muted)">No saved {activeConfig.label.toLowerCase()} match “{query}”.</p></div>
{:else}
  <div class="grid gap-3" data-testid="offline-results">
    {#each records as record (record.id)}
      <article class="ui-card p-4">
        {#if activeView === "products"}
          <div class="flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-between">
            <div class="min-w-0">
              <div class="flex flex-wrap items-center gap-2"><h2 class="font-semibold">{record.name}</h2><span class="ui-badge">{record.code}</span></div>
              <p class="mt-1 text-xs" style="color:var(--muted)">{record.product_group || "Uncategorized"}{record.supplier ? ` · ${record.supplier}` : ""}{record.tax_code ? ` · ${record.tax_code}` : ""}</p>
            </div>
            <div class="flex items-center gap-5 sm:text-right">
              <div><p class="text-xs" style="color:var(--muted)">Stock</p><p class="text-sm font-semibold">{record.stock_level ?? 0}</p></div>
              <div><p class="text-xs" style="color:var(--muted)">Price</p><p class="text-lg font-semibold">{formatMoney(record.selling_price)}</p></div>
            </div>
          </div>
        {:else if activeView === "services"}
          <div class="flex flex-col gap-3 sm:flex-row sm:items-start sm:justify-between">
            <div class="min-w-0"><div class="flex flex-wrap items-center gap-2"><h2 class="font-semibold">{record.name}</h2>{#if record.code}<span class="ui-badge">{record.code}</span>{/if}</div>{#if record.description}<p class="mt-1 text-sm" style="color:var(--muted)">{record.description}</p>{/if}</div>
            <div class="shrink-0 sm:text-right"><p class="text-lg font-semibold">{formatMoney(record.price)}</p><p class="text-xs" style="color:var(--muted)">{record.tax_code || "No tax code"}</p></div>
          </div>
        {:else if activeView === "customers"}
          <div class="flex flex-col gap-3 sm:flex-row sm:items-start sm:justify-between">
            <div class="min-w-0"><div class="flex flex-wrap items-center gap-2"><h2 class="font-semibold">{record.name}</h2>{#if record.member_number}<span class="ui-badge">Member {record.member_number}</span>{/if}</div><p class="mt-1 text-sm" style="color:var(--muted)">{[record.email, record.phone].filter(Boolean).join(" · ") || "No contact details"}</p>{#if customerAddress(record)}<p class="mt-1 text-xs" style="color:var(--muted)">{customerAddress(record)}</p>{/if}</div>
            {#if record.alert}<p class="max-w-md rounded-lg border border-amber-300 bg-amber-50 px-3 py-2 text-xs font-medium text-amber-900">{record.alert}</p>{/if}
          </div>
        {:else}
          <div class="flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-between">
            <div><div class="flex items-center gap-2"><h2 class="font-semibold">{record.name}</h2><span class="ui-badge">{record.code}</span></div><p class="mt-1 text-xs" style="color:var(--muted)">{[record.province_code, record.exemption_type].filter(Boolean).join(" · ") || "General tax code"}</p></div>
            <p class="text-lg font-semibold">{formatRate(record.rate)}</p>
          </div>
        {/if}
      </article>
    {/each}
  </div>
{/if}
