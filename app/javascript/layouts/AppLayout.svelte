<script>
  import { Link, router, usePage } from "@inertiajs/svelte"
  import { createConsumer } from "@rails/actioncable"
  import { onMount } from "svelte"
  import Bell from "@lucide/svelte/icons/bell"
  import Boxes from "@lucide/svelte/icons/boxes"
  import CircleDollarSign from "@lucide/svelte/icons/circle-dollar-sign"
  import ClipboardList from "@lucide/svelte/icons/clipboard-list"
  import CloudDownload from "@lucide/svelte/icons/cloud-download"
  import FileChartColumn from "@lucide/svelte/icons/file-chart-column"
  import Gift from "@lucide/svelte/icons/gift"
  import LayoutDashboard from "@lucide/svelte/icons/layout-dashboard"
  import LogOut from "@lucide/svelte/icons/log-out"
  import PackageSearch from "@lucide/svelte/icons/package-search"
  import ReceiptText from "@lucide/svelte/icons/receipt-text"
  import Search from "@lucide/svelte/icons/search"
  import Settings from "@lucide/svelte/icons/settings"
  import ShoppingCart from "@lucide/svelte/icons/shopping-cart"
  import UserRound from "@lucide/svelte/icons/user-round"
  import Users from "@lucide/svelte/icons/users"
  import Wrench from "@lucide/svelte/icons/wrench"
  import WifiOff from "@lucide/svelte/icons/wifi-off"
  import CommandPalette from "../pages/components/CommandPalette.svelte"
  import { connectionAvailable } from "../lib/connection.js"

  const page = usePage()
  let pageProps = page.props || {}
  let auth = pageProps.auth || {}
  let paths = pageProps.paths || {}
  let flash = pageProps.flash || {}
  let currentPath = page.url || "/"
  let dismissTimer
  let toast = null
  let toastTimer
  let cableConsumer
  let cableSubscription
  let online = typeof navigator === "undefined" ? true : navigator.onLine
  let connectionTimer
  let connectionFailures = 0
  let searchOpen = false

  $: authenticated = Boolean(auth.authenticated)
  $: pageTitle = pageProps.title || "Workspace"
  $: pageDescription = pageProps.description || ""
  $: commandMeta = pageProps.metrics_last_updated ? `updated ${pageProps.metrics_last_updated}` : pageDescription
  $: commandAction = buildCommandAction(pageProps)
  $: keys = contextualKeys(pageProps.view)
  $: navItems = [
    { label: "Dashboard", href: paths.root, icon: LayoutDashboard },
    { label: "Register", href: paths.register, icon: ShoppingCart },
    { label: "Orders", href: paths.orders, icon: ReceiptText },
    { label: "Products", href: paths.products, icon: Boxes },
    { label: "Services", href: paths.services, icon: Wrench },
    { label: "Customers", href: paths.customers, icon: Users },
    { label: "Inventory", href: paths.inventory, icon: PackageSearch },
    { label: "Cash drawer", href: paths.cash_drawer, icon: CircleDollarSign },
    { label: "Store tasks", href: paths.store_tasks, icon: ClipboardList },
    { label: "Reports", href: paths.reports, icon: FileChartColumn },
  ].filter((item) => item.href)

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
    pageProps = { ...(nextPage.props || {}) }
    auth = pageProps.auth || {}
    paths = pageProps.paths || {}
    flash = pageProps.flash || {}
    currentPath = nextPage.url || "/"
    searchOpen = false
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

  function unmodifiedLeftClick(event) {
    return event.button === 0 && !event.metaKey && !event.ctrlKey && !event.shiftKey && !event.altKey
  }

  function startRailNavigation(event, href, fullPage = false) {
    if (!href || !unmodifiedLeftClick(event)) return

    event.preventDefault()
    if (fullPage) window.location.assign(href)
    else router.visit(href)
  }

  function finishRailNavigation(event, href) {
    if (!href || !unmodifiedLeftClick(event)) return

    event.preventDefault()
  }

  function startRailKeyboardNavigation(event, href, fullPage = false) {
    if (!href || event.key !== "Enter") return

    event.preventDefault()
    if (fullPage) window.location.assign(href)
    else router.visit(href)
  }

  function buildCommandAction(props) {
    if (!props?.view) return null
    if (props.view === "dashboard" && props.actions?.register) return { label: "New sale", href: props.actions.register, key: "F2" }
    if (props.view === "resource_index" && props.can_create && props.actions?.new) {
      return { label: `New ${String(props.title || "record").toLowerCase().replace(/s$/, "")}`, href: props.actions.new }
    }
    if (props.view === "resource_form") return { label: props.form?.submit_label || "Save changes", form: "resource-form", key: "⌘S" }
    if (props.view === "resource_show" && props.actions?.edit) return { label: "Edit record", href: props.actions.edit }
    if (props.view === "report_form") return { label: "Generate report", form: "report-form" }
    if (props.view === "report_show" && props.actions?.excel) return { label: "Export Excel", href: props.actions.excel }
    if (props.view === "receipt") return { label: "Print receipt", print: true }
    if (props.view === "gift_certificate_show") return { label: "Print certificate", print: true }
    if (props.view === "refund") return { label: "Process refund", form: "refund-form" }
    if (props.view === "drawer_count") return { label: "Save drawer count", form: "drawer-count-form" }
    if (props.view === "reconcile") return { label: "Save reconciliation", form: "reconcile-form" }
    if (props.view === "inventory") return { label: "Commit restock", form: "inventory-form" }
    return null
  }

  function contextualKeys(view) {
    if (view === "register") return [["F4", "Cash"], ["F8", "Hold"], ["F12", "Complete"], ["Esc", "Void"]]
    if (view === "resource_form") return [["⌘S", "Save"], ["Esc", "Cancel"], ["⌘K", "Search"]]
    if (view === "resource_index") return [["/", "Filter"], ["⌘K", "Search"], ["F2", "New sale"]]
    if (view === "dashboard") return [["F2", "New sale"], ["F3", "Held"], ["⌘K", "Search"]]
    return [["F2", "New sale"], ["⌘K", "Search"]]
  }

  function keyboard(event) {
    const modifier = event.metaKey || event.ctrlKey
    if (modifier && event.key.toLowerCase() === "k") {
      event.preventDefault()
      searchOpen = true
      return
    }
    if (modifier && event.key.toLowerCase() === "s" && pageProps.view === "resource_form") {
      event.preventDefault()
      document.getElementById("resource-form")?.requestSubmit()
      return
    }
    if (event.key === "/" && pageProps.view === "resource_index" && !["INPUT", "TEXTAREA", "SELECT"].includes(event.target.tagName)) {
      event.preventDefault()
      document.getElementById("resource-search")?.focus()
      return
    }
    if (event.key === "F2") {
      event.preventDefault()
      if (pageProps.view === "register" && pageProps.actions?.new_order) router.post(pageProps.actions.new_order)
      else if (paths.register) router.visit(paths.register)
    }
    if (event.key === "F3" && pageProps.actions?.held) {
      event.preventDefault()
      router.visit(pageProps.actions.held)
    }
    if (pageProps.view === "register" && ["F4", "F5", "F6", "F7"].includes(event.key)) {
      event.preventDefault()
      const methods = { F4: "cash", F5: "debit", F6: "credit", F7: "gift_certificate" }
      window.dispatchEvent(new CustomEvent("console:tender", { detail: methods[event.key] }))
    }
    if (pageProps.view === "register" && event.key === "F8") {
      event.preventDefault()
      if (pageProps.actions?.hold) router.post(pageProps.actions.hold)
    }
    if (pageProps.view === "register" && event.key === "F12") {
      event.preventDefault()
      document.getElementById("complete_btn")?.click()
    }
  }
</script>

<svelte:window onkeydown={keyboard} />

{#if authenticated}
  <div class="app">
    <nav class="c-rail" aria-label="Application sections">
      <a class="c-mark" href={paths.root || "/"} aria-label="EI Point of Sale" onmousedown={(event) => startRailNavigation(event, paths.root || "/")} onclick={(event) => finishRailNavigation(event, paths.root || "/")} onkeydown={(event) => startRailKeyboardNavigation(event, paths.root || "/")}>EI</a>
      {#each navItems as item}
        {#if online}
          <a href={item.href} class="c-railitem" data-label={item.label} aria-label={item.label} aria-current={active(item.href) ? "page" : undefined} onmousedown={(event) => startRailNavigation(event, item.href)} onclick={(event) => finishRailNavigation(event, item.href)} onkeydown={(event) => startRailKeyboardNavigation(event, item.href)}>
            <svelte:component this={item.icon} />
          </a>
        {:else}
          <button class="c-railitem" data-label={item.label} aria-label={`${item.label} unavailable offline`} disabled><svelte:component this={item.icon} /></button>
        {/if}
      {/each}
      <span class="c-railspacer"></span>
      <span class="c-railrule"></span>
      <a href={paths.admin_gift_certificates} class="c-railitem" data-label="Gift certificates" aria-label="Gift certificates" aria-current={active(paths.admin_gift_certificates) ? "page" : undefined} onmousedown={(event) => startRailNavigation(event, paths.admin_gift_certificates)} onclick={(event) => finishRailNavigation(event, paths.admin_gift_certificates)} onkeydown={(event) => startRailKeyboardNavigation(event, paths.admin_gift_certificates)}><Gift /></a>
      <a href={paths.offline || "/offline"} class="c-railitem" data-label={online ? "Offline lookup" : "Offline mode"} aria-label={online ? "Offline lookup" : "Offline mode"} aria-current={active(paths.offline) ? "page" : undefined} onmousedown={(event) => startRailNavigation(event, paths.offline || "/offline", true)} onclick={(event) => finishRailNavigation(event, paths.offline || "/offline")} onkeydown={(event) => startRailKeyboardNavigation(event, paths.offline || "/offline", true)}>{#if online}<CloudDownload />{:else}<WifiOff />{/if}</a>
      {#if online && auth.admin}<a href={paths.admin_settings} class="c-railitem" data-label="Administration" aria-label="Administration" aria-current={active(paths.admin_settings) ? "page" : undefined} onmousedown={(event) => startRailNavigation(event, paths.admin_settings)} onclick={(event) => finishRailNavigation(event, paths.admin_settings)} onkeydown={(event) => startRailKeyboardNavigation(event, paths.admin_settings)}><Settings /></a>{/if}
      {#if online}<a href={paths.notifications || "/notifications"} class="c-railitem" data-label="Notifications" data-count={auth.unread_notifications || undefined} data-count-tone="bad" aria-label="Notifications" aria-current={active(paths.notifications) ? "page" : undefined} onmousedown={(event) => startRailNavigation(event, paths.notifications || "/notifications")} onclick={(event) => finishRailNavigation(event, paths.notifications || "/notifications")} onkeydown={(event) => startRailKeyboardNavigation(event, paths.notifications || "/notifications")}><Bell /></a>{/if}
      {#if online}<a href={paths.profile} class="c-railitem" data-label={auth.name || auth.email || "Profile"} aria-label="Profile" aria-current={active(paths.profile) ? "page" : undefined} onmousedown={(event) => startRailNavigation(event, paths.profile)} onclick={(event) => finishRailNavigation(event, paths.profile)} onkeydown={(event) => startRailKeyboardNavigation(event, paths.profile)}><UserRound /></a>{/if}
      <button class="c-railitem" data-label="Sign out" aria-label="Sign out" disabled={!online} onclick={() => router.delete(paths.session)}><LogOut /></button>
    </nav>

    <header class="c-cmdbar">
      <div class="c-path">
        <span class="c-path-current">{pageTitle}</span>
        {#if commandMeta}<span class="c-path-sep">·</span><span class="c-path-meta">{commandMeta}</span>{/if}
      </div>
      <button class="c-search" type="button" onclick={() => (searchOpen = true)}>
        <Search /><span>Search products, orders, customers…</span><kbd>⌘K</kbd>
      </button>
      <div class="c-actions">
        <span class="c-live"><span class={`c-dot ${online ? "c-dot-ok" : "c-dot-bad"}`}></span>{online ? "Online" : "Offline"} · <strong>{auth.store_name || "Store"}</strong></span>
        {#if commandAction?.href}<Link href={commandAction.href} class="c-btn c-btn-primary">{commandAction.label}{#if commandAction.key}<kbd>{commandAction.key}</kbd>{/if}</Link>
        {:else if commandAction?.form}<button form={commandAction.form} class="c-btn c-btn-primary" type="submit">{commandAction.label}{#if commandAction.key}<kbd>{commandAction.key}</kbd>{/if}</button>
        {:else if commandAction?.print}<button class="c-btn c-btn-primary" type="button" onclick={() => window.print()}>{commandAction.label}</button>{/if}
      </div>
    </header>

    <main class="app-content">
      {#if flash.notice}<div class="n-bar n-ok"><span>{flash.notice}</span><button class="k-btn k-btn-xs k-btn-quiet push" onclick={() => (flash = {})}>Dismiss</button></div>{/if}
      {#if flash.alert}<div class="n-bar n-bad"><span>{flash.alert}</span><button class="k-btn k-btn-xs k-btn-quiet push" onclick={() => (flash = {})}>Dismiss</button></div>{/if}
      <slot />
    </main>

    <footer class="c-statusbar">
      <span class="c-status-group"><span class={`c-dot ${online ? "c-dot-ok" : "c-dot-bad"}`}></span>{online ? "Online · live data" : "Offline · cached lookup"}</span>
      <span class="c-status-group">{auth.store_name || "Store workspace"}</span>
      <span class="c-status-group">{auth.name || auth.email} · <strong>{auth.admin ? "Admin" : "Staff"}</strong></span>
      <div class="c-keys">{#each keys as [key, label]}<span class="c-key"><kbd>{key}</kbd>{label}</span>{/each}</div>
    </footer>
  </div>
{:else}
  <main>
    {#if flash.notice}<div class="n-bar n-ok">{flash.notice}</div>{/if}
    {#if flash.alert}<div class="n-bar n-bad">{flash.alert}</div>{/if}
    <slot />
  </main>
{/if}

<CommandPalette open={searchOpen} onclose={() => (searchOpen = false)} />

{#if toast}
  <div class="toast" style="position:fixed;right:var(--space-4);bottom:calc(var(--statusbar-height) + var(--space-4));z-index:70" role="status">
    <div class="grow"><p class="toast-title">{toast.title}</p>{#if toast.body}<p>{toast.body}</p>{/if}{#if toast.url}<Link href={toast.url} onclick={() => (toast = null)}>Open</Link>{/if}</div>
    <button class="c-btn c-btn-quiet" type="button" aria-label="Dismiss notification" onclick={() => (toast = null)}>×</button>
  </div>
{/if}
