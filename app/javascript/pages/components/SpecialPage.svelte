<script>
  import { Link, router } from "@inertiajs/svelte"
  import PageHeader from "./PageHeader.svelte"
  export let view
  export let title
  export let description = ""
  export let details = []
  export let actions = []
  export let cards = []
  export let form = null
  export let order = null
  export let events = []
  export let store = null
  export let receipt_lines = []
  export let action = null
  export let errors = []
  export let session = null
  export let pending_reconciliation = null
  export let recent_sessions = []
  export let denominations = []
  export let reconciliation = null
  export let report = null
  export let notifications = []
  export let unread_count = 0
  export let certificate = null
  export let redemptions = []
  export let preview_lines = []
  export let files = []
  export let status = null
  export let recurring_tasks = []
  export let recent_imports = []

  let reportValues = Object.fromEntries((form?.parameters || []).map((parameter) => [parameter.key, ""]))
  let inventoryCode = ""
  let inventoryItems = []
  let inventoryFile
  let counts = Object.fromEntries(denominations.map((item) => [item.key, 0]))
  let notes = ""
  let reconcileValues = { debit_total: reconciliation?.debit_total || "", credit_total: reconciliation?.credit_total || "", notes: "" }
  let uploadFile
  let refundLines = (order?.lines || []).map((line) => ({ selected: false, order_line_id: line.id, quantity: line.refundable_quantity ?? line.quantity, restock: line.sellable_type === "Product" }))
  let refundReason = ""

  $: countTotal = denominations.reduce((sum, item) => sum + Number(counts[item.key] || 0) * item.value, 0)

  function perform(item) {
    if (item.full_reload) {
      if (item.method === "get") { window.location.assign(item.path); return }
      const submission = document.createElement("form")
      submission.method = "post"
      submission.action = item.path
      const csrf = document.querySelector('meta[name="csrf-token"]')?.content
      if (csrf) {
        const token = document.createElement("input")
        token.type = "hidden"
        token.name = "authenticity_token"
        token.value = csrf
        submission.appendChild(token)
      }
      document.body.appendChild(submission)
      submission.submit()
      return
    }
    if (item.method === "get") router.visit(item.path)
    else router[item.method](item.path)
  }
  function generateReport(event) { event.preventDefault(); router.post(form.action, { report: { report_type: form.report_type, parameters: reportValues } }) }
  function removeReport() { if (window.confirm("Delete this report?")) router.delete(actions.delete) }
  async function lookupInventory(event) {
    event.preventDefault()
    if (!inventoryCode.trim()) return
    const response = await fetch(`${actions.lookup}?code=${encodeURIComponent(inventoryCode.trim())}`, { headers: { Accept: "application/json" } })
    const product = await response.json()
    if (product.found && !inventoryItems.some((item) => item.id === product.id)) inventoryItems = [...inventoryItems, { ...product, quantity: 1, notes: "" }]
    inventoryCode = ""
  }
  function commitInventory() { router.post(actions.restock, { restocks: inventoryItems.map((item) => ({ product_id: item.id, quantity: item.quantity, notes: item.notes })) }) }
  function importInventory() { if (inventoryFile) router.post(actions.import, { csv_file: inventoryFile }, { forceFormData: true }) }
  function submitCount(event) { event.preventDefault(); router.post(action, { counts, notes }) }
  function submitReconciliation(event) { event.preventDefault(); router.post(action, reconcileValues) }
  function submitRefund(event) { event.preventDefault(); router.post(action, { refund_lines: refundLines.map((line) => ({ ...line, selected: line.selected ? "1" : "0", restock: line.restock ? "1" : "0" })), reason: refundReason }) }
  function submitOperationalUpload(event) { event.preventDefault(); if (uploadFile) router.post(actions[0].path, { file: uploadFile, preview: "1" }, { forceFormData: true }) }
</script>

{#if view === "cards"}
  <PageHeader {title} {description} />
  <section class="grid gap-3 sm:grid-cols-2 xl:grid-cols-3">{#each cards as card}<Link href={card.path} class="ui-card block p-4 transition hover:-translate-y-0.5"><h2 class="text-sm font-semibold">{card.title}</h2><p class="mt-1 text-xs" style="color:var(--muted)">{card.description}</p></Link>{/each}</section>
{:else if view === "report_form"}
  <PageHeader {title} {description} />
  <form class="ui-card p-4" onsubmit={generateReport}><div class="grid gap-4 sm:grid-cols-2">{#each form.parameters as parameter}<div><label class="ui-label" for={parameter.key}>{parameter.label}</label>{#if parameter.type === "select"}<select class="ui-input" id={parameter.key} required={parameter.required} bind:value={reportValues[parameter.key]}>{#each parameter.options || [] as option}<option value={Array.isArray(option) ? option[1] : option.value}>{Array.isArray(option) ? option[0] : option.label}</option>{/each}</select>{:else}<input class="ui-input" id={parameter.key} type={parameter.type === "integer" ? "number" : parameter.type} required={parameter.required} bind:value={reportValues[parameter.key]} />{/if}</div>{/each}</div><div class="mt-4 flex justify-end"><button class="ui-button ui-button-primary">Generate report</button></div></form>
{:else if view === "report_show"}
  <PageHeader {title} {description}><div class="flex flex-wrap gap-2"><Link href={actions.index} class="ui-button ui-button-secondary">Back</Link>{#if report.status === "completed"}<a href={actions.pdf} class="ui-button ui-button-secondary">PDF</a><a href={actions.excel} class="ui-button ui-button-primary">Excel</a>{/if}</div></PageHeader>
  <section class="ui-card p-4"><div class="flex items-center justify-between"><span class="ui-badge">{report.status}</span><span class="text-xs" style="color:var(--muted)">{report.created_at}</span></div>{#if ["pending", "processing"].includes(report.status)}<div class="mt-4 rounded-lg p-5 text-center text-sm" style="background:var(--surface-muted)">{report.status === "pending" ? "Report is queued for generation…" : "Report is being generated…"}</div>{:else if report.status === "failed"}<div class="mt-4 rounded-lg bg-red-50 p-4 text-red-900"><h2 class="font-semibold">Report generation failed</h2><p class="mt-1 text-sm">{report.error_message}</p></div>{:else if report.status === "completed"}{#if report.result_data?.summary}<div class="mt-4 grid gap-3 sm:grid-cols-2 lg:grid-cols-4">{#each Object.entries(report.result_data.summary) as [key, value]}<div class="rounded-lg border p-3" style="border-color:var(--border)"><p class="text-xs" style="color:var(--muted)">{key.replaceAll("_", " ")}</p><p class="mt-1 text-lg font-semibold">{value}</p></div>{/each}</div>{/if}{#if report.result_data?.chart}<div class="mt-4 rounded-lg border p-4" style="border-color:var(--border)"><h2 class="text-sm font-semibold">Chart</h2><div class="mt-3 flex h-44 items-end gap-3">{#each report.result_data.chart.labels || [] as label, index}<div class="flex min-w-12 flex-1 flex-col items-center justify-end gap-1"><span class="text-xs font-semibold">{report.result_data.chart.datasets?.[0]?.data?.[index] ?? 0}</span><div class="w-full max-w-14 rounded-t" style={`height:${Math.max(8, Number(report.result_data.chart.datasets?.[0]?.data?.[index] || 0) * 12)}px;background:var(--primary)`}></div><span class="max-w-20 truncate text-[10px]" style="color:var(--muted)">{label}</span></div>{/each}</div></div>{/if}{#if report.result_data?.table}<div class="ui-card mt-4 overflow-x-auto"><div class="ui-panel-header"><div><h2 class="text-sm font-semibold">Details</h2><p class="text-xs" style="color:var(--muted)">{report.result_data.table.length} records</p></div></div><table class="ui-table"><thead><tr>{#each report.table_columns as column}<th>{column.label}</th>{/each}</tr></thead><tbody>{#each report.result_data.table as row}<tr>{#each report.table_columns as column}<td>{row[column.key]}</td>{/each}</tr>{/each}</tbody></table></div>{/if}{/if}<h2 class="mt-4 text-sm font-semibold">Parameters</h2><pre class="mt-2 overflow-auto rounded-lg p-3 text-xs" style="background:var(--surface-muted)">{JSON.stringify(report.parameters, null, 2)}</pre><div class="mt-4 flex justify-end"><button class="ui-button ui-button-danger" onclick={removeReport}>Delete report</button></div></section>
{:else if view === "gift_certificate_show"}
  <PageHeader {title} {description}><div class="flex gap-2"><Link href={actions.index} class="ui-button ui-button-secondary">Back</Link><button class="ui-button ui-button-primary" onclick={() => window.print()}>Print Certificate</button></div></PageHeader>
  <section id="gift-certificate-print" class="ui-card mx-auto max-w-2xl border-2 p-8 text-center" style="border-color:var(--primary)"><p class="text-sm font-semibold uppercase tracking-[0.25em]" style="color:var(--primary)">{store?.name || "EI Point of Sale"}</p><h2 class="mt-6 text-3xl font-semibold">Gift Certificate</h2><p class="mt-6 font-mono text-xl tracking-wider">{certificate.code}</p><p class="mt-5 text-sm">Current balance: <strong class="text-2xl">{certificate.remaining_balance}</strong></p></section>
  <section class="mt-4 grid gap-4 lg:grid-cols-2"><div class="ui-card p-4"><h2 class="text-sm font-semibold">Details</h2><dl class="mt-3 space-y-2 text-sm">{#each Object.entries(certificate) as [key, value]}<div class="flex justify-between gap-4 border-b pb-2" style="border-color:var(--border)"><dt style="color:var(--muted)">{key.replaceAll("_", " ")}</dt><dd class="text-right">{value || "—"}</dd></div>{/each}</dl></div><div class="ui-card overflow-hidden"><div class="ui-panel-header"><h2 class="text-sm font-semibold">Redemption History</h2></div><table class="ui-table"><thead><tr><th>Order</th><th>Amount</th><th>Received by</th><th>Date</th></tr></thead><tbody>{#each redemptions as redemption}<tr><td><Link href={redemption.order_path}>{redemption.order}</Link></td><td>{redemption.amount}</td><td>{redemption.received_by}</td><td>{redemption.created_at}</td></tr>{:else}<tr><td colspan="4" class="text-center" style="color:var(--muted)">No redemptions yet.</td></tr>{/each}</tbody></table></div></section>
{:else if view === "receipt_template_show"}
  <PageHeader {title} {description}><div class="flex gap-2"><Link href={actions.index} class="ui-button ui-button-secondary">Back</Link><Link href={actions.edit} class="ui-button ui-button-primary">Edit</Link>{#if actions.activate}<button class="ui-button ui-button-secondary" onclick={() => router.patch(actions.activate)}>Activate</button>{/if}</div></PageHeader>
  <section class="grid gap-4 xl:grid-cols-2"><div class="ui-card p-4"><h2 class="text-sm font-semibold">Template details</h2><dl class="mt-3 grid gap-3 sm:grid-cols-2">{#each details as detail}<div><dt class="text-xs font-semibold uppercase" style="color:var(--muted)">{detail.label}</dt><dd class="mt-1 text-sm">{detail.value}</dd></div>{/each}</dl></div><div class="ui-card p-4"><h2 class="text-sm font-semibold">Preview</h2><pre class="mx-auto mt-3 max-w-md overflow-x-auto whitespace-pre font-mono text-xs" style="color:var(--foreground)">{preview_lines.join("\n")}</pre></div></section>
{:else if view === "backups"}
  <PageHeader {title} {description}><div class="flex gap-2">{#each actions as item}<button class="ui-button ui-button-secondary" onclick={() => perform(item)}>{item.label}</button>{/each}</div></PageHeader>
  <section class="ui-card p-4"><div class="flex items-center gap-3"><span class="ui-badge">{status}</span><div class="grid gap-x-8 gap-y-1 text-sm sm:grid-cols-3">{#each details as detail}<p><span style="color:var(--muted)">{detail.label}:</span> {detail.value}</p>{/each}</div></div></section>
  <section class="mt-4 grid gap-4 xl:grid-cols-2">{#each files as group}<div class="ui-card overflow-hidden"><div class="ui-panel-header"><h2 class="text-sm font-semibold">{group.label}</h2></div><table class="ui-table"><thead><tr><th>File</th><th>Date</th><th>Size</th><th></th></tr></thead><tbody>{#each group.items as item}<tr><td>{item.name}</td><td>{item.created_at}</td><td>{item.size}</td><td><a href={item.path} class="text-xs font-semibold" style="color:var(--primary)">Download</a></td></tr>{:else}<tr><td colspan="4" class="text-center" style="color:var(--muted)">No backups found.</td></tr>{/each}</tbody></table></div>{/each}</section>
{:else if view === "recurring_tasks"}
  <PageHeader {title} {description} />
  <section class="ui-card overflow-hidden"><table class="ui-table"><thead><tr><th>Task</th><th>Schedule</th><th>Job</th><th>Last run</th><th>Status</th><th></th></tr></thead><tbody>{#each recurring_tasks as item}<tr><td>{item.key}</td><td>{item.schedule}</td><td>{item.class_name}</td><td>{item.last_run_at || "Never"}</td><td><span class="ui-badge">{item.last_job_status}</span></td><td><button class="ui-button ui-button-secondary" onclick={() => router.post(item.run_path)}>Run now</button></td></tr>{:else}<tr><td colspan="6" class="text-center" style="color:var(--muted)">No recurring tasks configured.</td></tr>{/each}</tbody></table></section>
{:else if view === "order_show"}
  <PageHeader {title} {description}><div class="flex gap-2"><Link href={actions.index} class="ui-button ui-button-secondary">Back</Link>{#if ["draft", "held"].includes(order.status)}<Link href={actions.register} class="ui-button ui-button-primary">Open in register</Link>{/if}<Link href={actions.receipt} class="ui-button ui-button-secondary">Receipt</Link>{#if ["completed", "partially_refunded"].includes(order.status)}<Link href={actions.refund} class="ui-button ui-button-danger">Refund</Link>{/if}</div></PageHeader>
  <section class="grid gap-4 xl:grid-cols-[minmax(0,2fr)_minmax(18rem,1fr)]"><div class="ui-card overflow-hidden"><table class="ui-table"><thead><tr><th>Item</th><th>Qty</th><th class="text-right">Price</th><th class="text-right">Tax</th><th class="text-right">Total</th></tr></thead><tbody>{#each order.lines as line}<tr><td><strong>{line.name}</strong><br><span class="text-xs" style="color:var(--muted)">{line.code}</span></td><td>{line.quantity}</td><td class="money text-right">{line.unit_price}</td><td class="money text-right">{line.tax}</td><td class="money text-right">{line.total}</td></tr>{/each}</tbody></table></div><aside class="space-y-4"><div class="ui-card p-4"><span class="ui-badge">{order.status}</span><dl class="mt-3 space-y-2 text-sm"><div class="flex justify-between"><dt>Customer</dt><dd>{order.customer?.name || "Quick Sale"}</dd></div><div class="flex justify-between"><dt>Subtotal</dt><dd class="money">{order.subtotal}</dd></div><div class="flex justify-between"><dt>Tax</dt><dd class="money">{order.tax_total}</dd></div><div class="flex justify-between border-t pt-2 font-semibold" style="border-color:var(--border)"><dt>Total</dt><dd class="money">{order.total}</dd></div></dl></div><div class="ui-card p-4"><h2 class="text-sm font-semibold">Activity</h2><div class="mt-2 space-y-2">{#each events as event}<div class="border-l-2 pl-3 text-xs" style="border-color:var(--primary)"><strong>{event.type}</strong><p style="color:var(--muted)">{event.actor} · {event.at}</p></div>{/each}</div></div></aside></section>
{:else if view === "receipt"}
  <PageHeader {title}><div class="flex gap-2"><Link href={actions.order} class="ui-button ui-button-secondary">Back to order</Link><button class="ui-button ui-button-primary" onclick={() => window.print()}>Print</button></div></PageHeader>
  <article class="ui-card mx-auto max-w-md p-6 font-mono text-sm"><div class="text-center"><h2 class="text-lg font-bold">{store?.name}</h2><p>{[store?.address_line1, store?.city, store?.province, store?.postal_code].filter(Boolean).join(", ")}</p><p>{store?.phone}</p></div><hr class="my-4" style="border-color:var(--border)"><p>{order.number} · {order.completed_at}</p><div class="my-4 space-y-2">{#each order.lines as line}<div><div class="flex justify-between"><span>{line.quantity} × {line.name}</span><span>{line.total}</span></div></div>{/each}</div><hr class="my-4" style="border-color:var(--border)"><div class="flex justify-between text-base font-bold"><span>Total</span><span>{order.total}</span></div>{#if receipt_lines.length}<pre class="mt-4 whitespace-pre-wrap">{receipt_lines.join("\n")}</pre>{/if}</article>
{:else if view === "refund"}
  <PageHeader {title} {description} />
  <form onsubmit={submitRefund}><section class="ui-card overflow-hidden"><table class="ui-table"><thead><tr><th></th><th>Item</th><th>Original</th><th>Refund qty</th><th>Restock</th><th>Price</th></tr></thead><tbody>{#each order.lines as line, index}<tr><td><input type="checkbox" aria-label={`Refund ${line.name}`} bind:checked={refundLines[index].selected} /></td><td>{line.name}</td><td>{line.quantity}</td><td><input class="ui-input w-20!" aria-label={`Refund quantity for ${line.name}`} type="number" min="1" max={line.refundable_quantity ?? line.quantity} bind:value={refundLines[index].quantity} /></td><td>{#if line.sellable_type === "Product"}<input type="checkbox" aria-label={`Restock ${line.name}`} bind:checked={refundLines[index].restock} />{:else}N/A{/if}</td><td>{line.unit_price}</td></tr>{/each}</tbody></table><div class="border-t p-4" style="border-color:var(--border)"><label class="ui-label" for="refund-reason">Reason</label><textarea id="refund-reason" class="ui-input min-h-20" bind:value={refundReason}></textarea></div></section><div class="mt-3 flex justify-end"><button class="ui-button ui-button-danger">Process refund</button></div></form>
{:else if view === "inventory"}
  <PageHeader {title} {description} />
  <section class="grid gap-4 xl:grid-cols-[minmax(0,2fr)_minmax(18rem,1fr)]"><div><form class="mb-3 flex gap-2" onsubmit={lookupInventory}><label class="sr-only" for="inventory-code">Product code</label><input id="inventory-code" class="ui-input" placeholder="Enter or scan product code" bind:value={inventoryCode} /><button class="ui-button ui-button-primary">Add product</button></form><div class="ui-card overflow-hidden"><table class="ui-table"><thead><tr><th>Code</th><th>Product</th><th>Current</th><th>Quantity</th><th>Notes</th><th></th></tr></thead><tbody>{#each inventoryItems as item, index}<tr><td>{item.code}</td><td>{item.name}</td><td>{item.stock_level}</td><td><input class="ui-input w-20!" aria-label={`Quantity for ${item.name}`} type="number" min="1" bind:value={item.quantity} /></td><td><input class="ui-input" aria-label={`Notes for ${item.name}`} bind:value={item.notes} /></td><td><button style="color:var(--danger)" aria-label={`Remove ${item.name}`} onclick={() => (inventoryItems = inventoryItems.filter((_, itemIndex) => itemIndex !== index))}>×</button></td></tr>{:else}<tr><td colspan="6" class="py-8 text-center" style="color:var(--muted)">No products added.</td></tr>{/each}</tbody></table>{#if inventoryItems.length}<footer class="flex justify-end border-t p-3" style="border-color:var(--border)"><button class="ui-button ui-button-primary" onclick={commitInventory}>Commit restock</button></footer>{/if}</div></div><aside class="ui-card h-fit p-4"><h2 class="text-sm font-semibold">Import CSV</h2><p class="mt-1 text-xs" style="color:var(--muted)">Use code, quantity, and optional notes columns.</p><label class="sr-only" for="inventory-file">CSV file</label><input id="inventory-file" class="ui-input mt-3" type="file" accept=".csv" onchange={(event) => (inventoryFile = event.currentTarget.files?.[0])} /><button class="ui-button ui-button-secondary mt-2 w-full" onclick={importInventory}>Upload and restock</button></aside></section>
{:else if view === "cash_drawer"}
  <PageHeader {title} {description}><Link href={actions.history} class="ui-button ui-button-secondary">History</Link></PageHeader>
  <section class="grid gap-4 lg:grid-cols-2"><div class="ui-card p-5">{#if session}<span class="ui-badge">Open</span><h2 class="mt-3 text-lg font-semibold">{session.opening_total} opening float</h2><p class="mt-1 text-sm" style="color:var(--muted)">Opened {session.opened_at} by {session.opened_by}</p><Link href={actions.close} class="ui-button ui-button-primary mt-5">Close register</Link>{:else}<span class="ui-badge">Closed</span><h2 class="mt-3 text-lg font-semibold">The register is closed</h2>{#if pending_reconciliation}<Link href={actions.reconcile} class="ui-button ui-button-primary mt-5">Reconcile terminal</Link>{:else}<Link href={actions.open} class="ui-button ui-button-primary mt-5">Open register</Link>{/if}{/if}</div><div class="ui-card overflow-hidden"><div class="ui-panel-header"><h2 class="text-sm font-semibold">Recent sessions</h2></div><div class="divide-y" style="border-color:var(--border)">{#each recent_sessions as item}<Link href={item.path} class="flex justify-between p-3 text-sm"><span>{item.opened_at}</span><span class="money">{item.closing_total}</span></Link>{:else}<p class="p-5 text-sm" style="color:var(--muted)">No completed sessions.</p>{/each}</div></div></section>
{:else if view === "drawer_count"}
  <PageHeader {title} {description} />
  <form class="ui-card p-4" onsubmit={submitCount}><div class="grid gap-3 sm:grid-cols-2 lg:grid-cols-3">{#each denominations as item}<label class="grid grid-cols-[1fr_5rem_6rem] items-center gap-2 rounded-lg border p-2 text-sm" style="border-color:var(--border)"><span>{item.label}</span><input class="ui-input text-center" type="number" min="0" bind:value={counts[item.key]} /><span class="money text-right">${(Number(counts[item.key] || 0) * item.value).toFixed(2)}</span></label>{/each}</div><div class="mt-4 flex items-center justify-between rounded-lg p-4" style="background:var(--surface-muted)"><span class="font-semibold">Grand total</span><span class="money text-2xl font-semibold">${countTotal.toFixed(2)}</span></div><label class="ui-label mt-4" for="drawer-notes">Notes</label><textarea id="drawer-notes" class="ui-input min-h-20" bind:value={notes}></textarea><div class="mt-4 flex justify-end"><button class="ui-button ui-button-primary">Continue</button></div></form>
{:else if view === "reconcile"}
  <PageHeader {title} {description} />
  <form class="ui-card max-w-2xl p-4" onsubmit={submitReconciliation}><div class="grid gap-4 sm:grid-cols-2"><div><label class="ui-label" for="debit-total">Debit terminal total</label><input id="debit-total" class="ui-input" type="number" step="0.01" bind:value={reconcileValues.debit_total} /><p class="mt-1 text-xs" style="color:var(--muted)">Expected {reconciliation.expected_debit_total}</p></div><div><label class="ui-label" for="credit-total">Credit terminal total</label><input id="credit-total" class="ui-input" type="number" step="0.01" bind:value={reconcileValues.credit_total} /><p class="mt-1 text-xs" style="color:var(--muted)">Expected {reconciliation.expected_credit_total}</p></div></div><label class="ui-label mt-4" for="reconcile-notes">Notes</label><textarea id="reconcile-notes" class="ui-input" bind:value={reconcileValues.notes}></textarea><div class="mt-4 flex justify-end"><button class="ui-button ui-button-primary">Save reconciliation</button></div></form>
{:else if view === "notifications"}
  <PageHeader {title} description={`${unread_count} unread`}><div class="flex gap-2"><button class="ui-button ui-button-secondary" onclick={() => router.patch(actions.mark_all)}>Mark all read</button><button class="ui-button ui-button-danger" onclick={() => router.delete(actions.clear_all)}>Clear all</button></div></PageHeader><section class="ui-card divide-y" style="border-color:var(--border)">{#each notifications as notification}<article class="p-4" class:opacity-60={notification.read}><div class="flex justify-between gap-3"><h2 class="text-sm font-semibold">{notification.title}</h2><span class="text-xs" style="color:var(--muted)">{notification.at}</span></div><p class="mt-1 text-sm" style="color:var(--muted)">{notification.body}</p><div class="mt-2 flex gap-3">{#if notification.url}<Link href={notification.url} class="text-xs font-semibold" style="color:var(--primary)">Open</Link>{/if}<button class="text-xs" style="color:var(--danger)" onclick={() => router.delete(notification.path)}>Delete</button></div></article>{:else}<p class="p-8 text-center text-sm" style="color:var(--muted)">No notifications.</p>{/each}</section>
{:else}
  <PageHeader {title} {description}><div class="flex flex-wrap gap-2">{#each actions as item}{#if !item.upload}<button class="ui-button ui-button-secondary" onclick={() => perform(item)}>{item.label}</button>{/if}{/each}</div></PageHeader>
  {#if errors.length}<div class="mb-4 rounded-lg border border-red-300 bg-red-50 p-3 text-sm text-red-900">{errors.join(" · ")}</div>{/if}
  {#if actions[0]?.upload}<form class="ui-card mb-4 flex items-end gap-3 p-4" onsubmit={submitOperationalUpload}><div class="flex-1"><label class="ui-label" for="operation-file">CSV file</label><input id="operation-file" class="ui-input" type="file" accept=".csv" onchange={(event) => (uploadFile = event.currentTarget.files?.[0])} /></div><button class="ui-button ui-button-primary">Preview import</button></form>{/if}
  <section class="ui-card overflow-hidden"><dl class="grid sm:grid-cols-2">{#each details as detail}<div class="border-b p-4 sm:border-r" style="border-color:var(--border)"><dt class="text-xs font-semibold uppercase tracking-wide" style="color:var(--muted)">{detail.label}</dt><dd class="mt-1 wrap-break-word text-sm">{typeof detail.value === "object" ? JSON.stringify(detail.value) : detail.value}</dd></div>{:else}<p class="p-6 text-sm" style="color:var(--muted)">No additional details.</p>{/each}</dl></section>
  {#if recent_imports.length}<section class="ui-card mt-4 overflow-hidden"><div class="ui-panel-header"><h2 class="text-sm font-semibold">Recent imports</h2></div><table class="ui-table"><thead><tr><th>File</th><th>Status</th><th>Date</th></tr></thead><tbody>{#each recent_imports as item}<tr><td><Link href={item.path}>{item.file_name}</Link></td><td>{item.status}</td><td>{item.created_at}</td></tr>{/each}</tbody></table></section>{/if}
{/if}
