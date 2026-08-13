<script>
  import { Link } from "@inertiajs/svelte"
  import EmptyState from "./EmptyState.svelte"
  import PanelHeader from "./PanelHeader.svelte"
  import StatusTag from "./StatusTag.svelte"
  import { stateTone } from "../../lib/design-system.js"

  export let metrics = []
  export let metrics_last_updated = null
  export let drawer = null
  export let recent_orders = []
  export let tasks = []
  export let actions = {}
</script>

<section class="screen">
  <div class="m-strip" style={`grid-template-columns:repeat(${Math.max(1, metrics.length)},minmax(0,1fr))`}>
    {#each metrics as metric}
      {#if metric.path}
        <Link href={metric.path} class={`m-cell ${/low|overdue|variance/i.test(metric.key || metric.label) ? "m-cell-alert" : ""}`}>
          <p class="m-label">{metric.label}</p><p class="m-value">{metric.value}</p><p class="m-note">{metric.description}</p>
        </Link>
      {:else}
        <div class:m-cell-alert={/low|overdue|variance/i.test(metric.key || metric.label)} class="m-cell">
          <p class="m-label">{metric.label}</p><p class="m-value">{metric.value}</p><p class="m-note">{metric.description}</p>
        </div>
      {/if}
    {/each}
  </div>

  <div class={`n-bar ${drawer ? "n-ok" : "n-warn"}`}>
    <span><strong>{drawer ? "Drawer open" : "Drawer closed"}.</strong>{" "}{#if drawer}{drawer.opening_total} float · opened by {drawer.opened_by}.{:else}Open the drawer before the first sale.{/if}</span>
    <span class="n-bar-actions"><Link class="k-btn k-btn-xs" href={drawer ? actions.close_drawer : actions.open_drawer}>{drawer ? "Close drawer" : "Open drawer"}</Link></span>
  </div>

  <div class="p-split" style="grid-template-columns:minmax(0,1fr) 320px">
    <section class="p-region">
      <PanelHeader title="Recent orders" count={`${recent_orders.length} shown${metrics_last_updated ? ` · metrics ${metrics_last_updated}` : ""}`}><Link href={actions.orders} class="k-btn k-btn-xs k-btn-quiet">Order history</Link></PanelHeader>
      <div class="t-wrap">
        {#if recent_orders.length}
          <table class="t" style="min-width:760px">
            <thead><tr><th>Order</th><th>Customer</th><th>State</th><th class="r">Total</th><th>Created</th><th></th></tr></thead>
            <tbody>
              {#each recent_orders as order}
                <tr data-state={stateTone(order.status)}>
                  <td><Link href={order.path} class="data">{order.number}</Link></td>
                  <td>{order.customer || "Quick sale"}</td>
                  <td><StatusTag value={order.status} /></td>
                  <td class="r data">{order.total}</td>
                  <td class="data faint">{order.created_at}</td>
                  <td class="r"><Link href={order.path} class="k-btn k-btn-xs k-btn-quiet">Open</Link></td>
                </tr>
              {/each}
            </tbody>
          </table>
        {:else}<EmptyState title="No orders yet" body="Start a new sale from the command bar." />{/if}
      </div>
    </section>

    <aside class="p-region">
      <PanelHeader title="Needs attention" count={tasks.length}><Link href={actions.tasks} class="k-btn k-btn-xs k-btn-quiet">All tasks</Link></PanelHeader>
      <div class="p-body-flush">
        {#each tasks as task}
          <Link href={task.path} class="list-row" data-state={task.overdue ? "warn" : stateTone(task.status)}>
            <span class="grow col"><strong>{task.title}</strong><span class="faint">{task.due_date ? `Due ${task.due_date}` : "No due date"}</span></span>
            <StatusTag value={task.status} tone={task.overdue ? "warn" : null} />
          </Link>
        {:else}<EmptyState title="Nothing assigned" body="New tasks assigned to you will appear here." />{/each}
      </div>
      <PanelHeader title="Jump to" />
      <div class="p-body" style="display:grid;grid-template-columns:1fr 1fr;gap:var(--space-1-5)">
        <Link class="k-key" href={actions.register}>New sale<span class="k-key-sub">F2</span></Link>
        <Link class="k-key" href={actions.orders}>Orders<span class="k-key-sub">F3 held</span></Link>
        <Link class="k-key" href={actions.cash_drawer}>Drawer<span class="k-key-sub">Count</span></Link>
        <Link class="k-key" href={actions.tasks}>Tasks<span class="k-key-sub">Assigned</span></Link>
      </div>
    </aside>
  </div>
</section>
