<script>
  import { Link } from "@inertiajs/svelte"
  import PageHeader from "./PageHeader.svelte"
  export let title
  export let description
  export let metrics = []
  export let metrics_last_updated = null
  export let drawer = null
  export let recent_orders = []
  export let tasks = []
  export let actions = {}
</script>

<PageHeader {title} {description}><Link href={actions.register} class="ui-button ui-button-primary">Open register</Link></PageHeader>

<section class="ui-card mb-4 flex flex-wrap items-center gap-2 px-4 py-3 text-sm">
  <span class="size-2 rounded-full" class:bg-emerald-500={drawer} class:bg-amber-500={!drawer}></span>
  <strong>{drawer ? "Register open" : "Register closed"}</strong>
  {#if drawer}<span style="color:var(--muted)">{drawer.opening_total} float · opened by {drawer.opened_by}</span>{/if}
  <Link class="ml-auto font-semibold" style="color:var(--primary)" href={drawer ? actions.close_drawer : actions.open_drawer}>{drawer ? "Close" : "Open register"}</Link>
</section>

{#if metrics_last_updated}<p class="mb-2 text-xs" style="color:var(--muted)">Metrics updated {metrics_last_updated}</p>{/if}
<section class="mb-4 grid gap-3 sm:grid-cols-2 xl:grid-cols-4">
  {#each metrics as metric}
    {#if metric.path}
      <Link href={metric.path} class="ui-card block p-4">
        <p class="text-xs font-medium" style="color:var(--muted)">{metric.label}</p>
        <p class="mt-1 text-2xl font-semibold money">{metric.value}</p>
        <p class="mt-1 text-xs" style="color:var(--muted)">{metric.description}</p>
      </Link>
    {:else}
      <div class="ui-card block p-4">
        <p class="text-xs font-medium" style="color:var(--muted)">{metric.label}</p>
        <p class="mt-1 text-2xl font-semibold money">{metric.value}</p>
        <p class="mt-1 text-xs" style="color:var(--muted)">{metric.description}</p>
      </div>
    {/if}
  {/each}
</section>

<section class="grid gap-4 xl:grid-cols-[minmax(0,2fr)_minmax(18rem,1fr)]">
  <div class="ui-card overflow-hidden">
    <div class="ui-panel-header"><h2 class="text-sm font-semibold">Recent orders</h2><Link href={actions.orders} class="text-xs font-semibold" style="color:var(--primary)">View all</Link></div>
    <div class="overflow-x-auto"><table class="ui-table"><thead><tr><th>Order</th><th>Customer</th><th>Status</th><th class="text-right">Total</th><th>Created</th></tr></thead><tbody>
      {#each recent_orders as order}<tr><td><Link href={order.path} class="font-semibold" style="color:var(--primary)">{order.number}</Link></td><td>{order.customer}</td><td><span class="ui-badge">{order.status}</span></td><td class="money text-right">{order.total}</td><td>{order.created_at}</td></tr>{:else}<tr><td colspan="5" class="text-center" style="color:var(--muted)">No orders yet.</td></tr>{/each}
    </tbody></table></div>
  </div>
  <div class="ui-card overflow-hidden">
    <div class="ui-panel-header"><h2 class="text-sm font-semibold">Your tasks</h2><Link href={actions.tasks} class="text-xs font-semibold" style="color:var(--primary)">All tasks</Link></div>
    <div class="space-y-2 p-3">{#each tasks as task}<Link href={task.path} class="block rounded-lg border p-3" style="border-color:var(--border)"><div class="flex items-center justify-between gap-2"><span class="truncate text-sm font-medium">{task.title}</span><span class="ui-badge">{task.status}</span></div>{#if task.due_date}<p class="mt-1 text-xs" style="color:{task.overdue ? 'var(--danger)' : 'var(--muted)'}">Due {task.due_date}</p>{/if}</Link>{:else}<p class="p-4 text-center text-sm" style="color:var(--muted)">Nothing assigned.</p>{/each}</div>
  </div>
</section>
