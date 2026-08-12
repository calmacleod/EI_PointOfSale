<script>
  import { Link, router, usePage } from "@inertiajs/svelte"
  import { createConsumer } from "@rails/actioncable"
  import { onMount } from "svelte"
  import Bell from "@lucide/svelte/icons/bell"
  import Boxes from "@lucide/svelte/icons/boxes"
  import ClipboardList from "@lucide/svelte/icons/clipboard-list"
  import FileChartColumn from "@lucide/svelte/icons/file-chart-column"
  import CloudDownload from "@lucide/svelte/icons/cloud-download"
  import LayoutDashboard from "@lucide/svelte/icons/layout-dashboard"
  import Menu from "@lucide/svelte/icons/menu"
  import PackageSearch from "@lucide/svelte/icons/package-search"
  import ReceiptText from "@lucide/svelte/icons/receipt-text"
  import Settings from "@lucide/svelte/icons/settings"
  import ShoppingCart from "@lucide/svelte/icons/shopping-cart"
  import Users from "@lucide/svelte/icons/users"
  import Wrench from "@lucide/svelte/icons/wrench"
  import WifiOff from "@lucide/svelte/icons/wifi-off"
  import { connectionAvailable } from "../lib/connection.js"

  const page = usePage()
  let auth = page.props.auth || {}
  let paths = page.props.paths || {}
  let flash = page.props.flash || {}
  let currentPath = page.url || "/"
  let mobileOpen = false
  let dismissTimer
  let toast = null
  let toastTimer
  let cableConsumer
  let cableSubscription
  let online = typeof navigator === "undefined" ? true : navigator.onLine
  let connectionTimer
  let connectionFailures = 0

  $: authenticated = Boolean(auth.authenticated)
  $: navItems = [
    ["Dashboard", paths.root, LayoutDashboard],
    ["Register", paths.register, ShoppingCart],
    ["Orders", paths.orders, ReceiptText],
    ["Products", paths.products, Boxes],
    ["Services", paths.services, Wrench],
    ["Customers", paths.customers, Users],
    ["Inventory", paths.inventory, PackageSearch],
    ["Tasks", paths.store_tasks, ClipboardList],
    ["Reports", paths.reports, FileChartColumn],
  ].filter((item) => item[1])

  onMount(() => {
    const stop = router.on("navigate", (event) => syncPage(event.detail.page))
    const syncConnection = async () => {
      const available = await connectionAvailable()
      connectionFailures = available ? 0 : connectionFailures + 1
      online = available
      syncCable()
      if (connectionFailures >= 2 && currentPath !== paths.offline && !currentPath.startsWith("/offline")) {
        window.location.assign(paths.offline || "/offline")
      }
    }
    window.addEventListener("online", syncConnection)
    window.addEventListener("offline", syncConnection)
    syncConnection()
    connectionTimer = window.setInterval(syncConnection, 5_000)
    syncCable()
    scheduleDismiss()
    return () => {
      stop()
      if (dismissTimer) window.clearTimeout(dismissTimer)
      if (toastTimer) window.clearTimeout(toastTimer)
      if (connectionTimer) window.clearInterval(connectionTimer)
      window.removeEventListener("online", syncConnection)
      window.removeEventListener("offline", syncConnection)
      disconnectCable()
    }
  })

  function syncPage(nextPage) {
    auth = nextPage.props.auth || {}
    paths = nextPage.props.paths || {}
    flash = nextPage.props.flash || {}
    currentPath = nextPage.url || "/"
    mobileOpen = false
    syncCable()
    scheduleDismiss()
  }

  function syncCable() {
    if (!auth.authenticated || !online) {
      disconnectCable()
      return
    }
    if (cableSubscription) return

    cableConsumer = createConsumer()
    cableSubscription = cableConsumer.subscriptions.create(
      { channel: "NotificationChannel" },
      { received: showNotification },
    )
  }

  function disconnectCable() {
    cableSubscription?.unsubscribe()
    cableConsumer?.disconnect()
    cableSubscription = undefined
    cableConsumer = undefined
  }

  function showNotification(notification) {
    if (notification.persistent) {
      auth = { ...auth, unread_notifications: Number(auth.unread_notifications || 0) + 1 }
    }
    toast = notification
    if (toastTimer) window.clearTimeout(toastTimer)
    toastTimer = window.setTimeout(() => (toast = null), 6000)
  }

  function scheduleDismiss() {
    if (dismissTimer) window.clearTimeout(dismissTimer)
    if (!flash.notice && !flash.alert) return
    dismissTimer = window.setTimeout(() => (flash = {}), 4500)
  }

  function active(href) {
    if (!href) return false
    if (href === "/") return currentPath === "/" || currentPath.startsWith("/?")
    return currentPath === href || currentPath.startsWith(`${href}/`) || currentPath.startsWith(`${href}?`)
  }
</script>

{#if authenticated}
  <div class="min-h-screen lg:grid lg:grid-cols-[15rem_minmax(0,1fr)]">
    <header class="sticky top-0 z-40 flex h-12 items-center gap-3 border-b px-3 lg:hidden" style="border-color:var(--border);background:var(--surface)">
      <button class="ui-button ui-button-secondary min-h-8! px-2!" aria-label="Open navigation" onclick={() => (mobileOpen = !mobileOpen)}><Menu class="size-4" /></button>
      <span class="flex-1 text-sm font-semibold">EI Point of Sale</span>
      {#if online}<Link href={paths.notifications || "/notifications"} class="relative"><Bell class="size-4" />{#if auth.unread_notifications}<span class="absolute -right-2 -top-2 rounded-full bg-red-600 px-1 text-[10px] text-white">{auth.unread_notifications}</span>{/if}</Link>{:else}<WifiOff class="size-4" />{/if}
    </header>

    <aside class="fixed inset-y-0 left-0 z-30 w-60 border-r p-3 transition-transform lg:sticky lg:top-0 lg:h-screen lg:translate-x-0 {mobileOpen ? 'translate-x-0' : '-translate-x-full'}" style="border-color:var(--border);background:var(--surface)">
      <div class="mb-5 flex items-center gap-3 px-2 py-1">
        <span class="flex size-9 items-center justify-center rounded-lg text-sm font-bold" style="background:var(--primary);color:var(--primary-foreground)">EI</span>
        <div><p class="text-sm font-semibold">Point of Sale</p><p class="text-xs" style="color:var(--muted)">{auth.store_name || "Store workspace"}</p></div>
      </div>
      <nav class="space-y-1">
        {#each navItems as [label, href, Icon]}
          {#if online}
            <Link href={href} prefetch="hover" class="flex items-center gap-3 rounded-lg px-3 py-2 text-sm font-medium transition-colors" style={`background:${active(href) ? "var(--primary)" : "transparent"};color:${active(href) ? "var(--primary-foreground)" : "var(--foreground)"}`}>
              <svelte:component this={Icon} class="size-4" />{label}
            </Link>
          {:else}
            <span class="flex cursor-not-allowed items-center gap-3 rounded-lg px-3 py-2 text-sm font-medium opacity-40"><svelte:component this={Icon} class="size-4" />{label}</span>
          {/if}
        {/each}
      </nav>
      <div class="absolute inset-x-3 bottom-3 space-y-1 border-t pt-3" style="border-color:var(--border)">
        <a href={paths.offline || "/offline"} class="flex items-center gap-3 rounded-lg px-3 py-2 text-sm font-medium hover:bg-black/5" style={`background:${active(paths.offline) ? "var(--primary)" : "transparent"};color:${active(paths.offline) ? "var(--primary-foreground)" : "var(--foreground)"}`}>
          {#if online}<CloudDownload class="size-4" />Offline lookup{:else}<WifiOff class="size-4" />Offline mode{/if}
        </a>
        {#if online}<Link href={paths.notifications || "/notifications"} class="flex items-center gap-3 rounded-lg px-3 py-2 text-sm font-medium hover:bg-black/5"><Bell class="size-4" />Notifications{#if auth.unread_notifications}<span class="ui-badge ml-auto">{auth.unread_notifications}</span>{/if}</Link>{/if}
        {#if online && auth.admin}<Link href={paths.admin_settings} class="flex items-center gap-3 rounded-lg px-3 py-2 text-sm font-medium hover:bg-black/5"><Settings class="size-4" />Administration</Link>{/if}
        {#if online}<Link href={paths.profile} class="block truncate rounded-lg px-3 py-2 text-sm hover:bg-black/5">{auth.name || auth.email}</Link>{:else}<span class="block truncate rounded-lg px-3 py-2 text-sm opacity-40">{auth.name || auth.email}</span>{/if}
        <button class="w-full rounded-lg px-3 py-2 text-left text-xs font-medium disabled:opacity-40" style="color:var(--muted)" disabled={!online} onclick={() => router.delete(paths.session)}>Sign out</button>
      </div>
    </aside>

    {#if mobileOpen}<button class="fixed inset-0 z-20 bg-black/45 lg:hidden" aria-label="Close navigation" onclick={() => (mobileOpen = false)}></button>{/if}

    <main class="min-w-0 px-3 py-4 sm:px-5 lg:px-7 lg:py-6">
      <div class="mx-auto max-w-7xl">
        {#if flash.notice}<div class="mb-4 rounded-lg border border-emerald-300 bg-emerald-50 px-4 py-3 text-sm text-emerald-900">{flash.notice}</div>{/if}
        {#if flash.alert}<div class="mb-4 rounded-lg border border-red-300 bg-red-50 px-4 py-3 text-sm text-red-900">{flash.alert}</div>{/if}
        <slot />
      </div>
    </main>
  </div>
{:else}
  <main class="min-h-screen px-4 py-8">
    <div class="mx-auto flex min-h-[calc(100vh-4rem)] max-w-md items-center">
      <div class="w-full">
        {#if flash.notice}<div class="mb-4 rounded-lg border border-emerald-300 bg-emerald-50 px-4 py-3 text-sm text-emerald-900">{flash.notice}</div>{/if}
        {#if flash.alert}<div class="mb-4 rounded-lg border border-red-300 bg-red-50 px-4 py-3 text-sm text-red-900">{flash.alert}</div>{/if}
        <slot />
      </div>
    </div>
  </main>
{/if}

{#if toast}
  <div class="ui-card fixed bottom-4 right-4 z-50 w-[min(24rem,calc(100vw-2rem))] p-4 shadow-xl" role="status">
    <div class="flex items-start justify-between gap-3"><div><p class="text-sm font-semibold">{toast.title}</p>{#if toast.body}<p class="mt-1 text-sm" style="color:var(--muted)">{toast.body}</p>{/if}</div><button type="button" aria-label="Dismiss notification" style="color:var(--muted)" onclick={() => (toast = null)}>×</button></div>
    {#if toast.url}<Link href={toast.url} class="mt-2 inline-block text-xs font-semibold" style="color:var(--primary)" onclick={() => (toast = null)}>Open</Link>{/if}
  </div>
{/if}
