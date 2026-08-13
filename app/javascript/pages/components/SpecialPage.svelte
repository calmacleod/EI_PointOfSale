<script>
  import { Deferred, Link, router } from "@inertiajs/svelte"
  import ConfirmModal from "./ConfirmModal.svelte"
  import DeferredPanel from "./DeferredPanel.svelte"
  import EmptyState from "./EmptyState.svelte"
  import Pagination from "./Pagination.svelte"
  import PanelHeader from "./PanelHeader.svelte"
  import StatusTag from "./StatusTag.svelte"
  import { displayValue, machineField, stateTone } from "../../lib/design-system.js"

  export let view
  export let title = ""
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
  export let query = {}
  export let pagination = null
  export let pagination_path = null

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
  let showReportDelete = false
  let showRefundPrompt = false

  $: countTotal = denominations.reduce((sum, item) => sum + Number(counts[item.key] || 0) * item.value, 0)
  $: selectedRefunds = refundLines.filter((line) => line.selected)

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
  function removeReport() { showReportDelete = false; router.delete(actions.delete) }
  async function lookupInventory(event) {
    event.preventDefault()
    if (!inventoryCode.trim()) return
    const response = await fetch(`${actions.lookup}?code=${encodeURIComponent(inventoryCode.trim())}`, { headers: { Accept: "application/json" } })
    const product = await response.json()
    if (product.found && !inventoryItems.some((item) => item.id === product.id)) inventoryItems = [...inventoryItems, { ...product, quantity: 1, notes: "" }]
    inventoryCode = ""
  }
  function commitInventory(event) { event?.preventDefault(); if (inventoryItems.length) router.post(actions.restock, { restocks: inventoryItems.map((item) => ({ product_id: item.id, quantity: item.quantity, notes: item.notes })) }) }
  function importInventory() { if (inventoryFile) router.post(actions.import, { csv_file: inventoryFile }, { forceFormData: true }) }
  function submitCount(event) { event.preventDefault(); router.post(action, { counts, notes }) }
  function submitReconciliation(event) { event.preventDefault(); router.post(action, reconcileValues) }
  function requestRefund(event) { event.preventDefault(); if (selectedRefunds.length) showRefundPrompt = true }
  function submitRefund() { showRefundPrompt = false; router.post(action, { refund_lines: refundLines.map((line) => ({ ...line, selected: line.selected ? "1" : "0", restock: line.restock ? "1" : "0" })), reason: refundReason }) }
  function submitOperationalUpload(event) { event.preventDefault(); if (uploadFile) router.post(actions[0].path, { file: uploadFile, preview: "1" }, { forceFormData: true }) }
  function chartHeight(value, values) { const numbers = values.map((item) => Number(item || 0)); const maximum = Math.max(...numbers, 1); return `${Math.max(4, (Number(value || 0) / maximum) * 100)}%` }
</script>

<svelte:head><meta name="application-screen" content={title} /></svelte:head>

{#if view === "cards"}
  <section class="screen">
    <section class="p-region">
      <PanelHeader title="Administration" count={`${cards.length} sections`} />
      <div class="console-grid" style="grid-template-columns:repeat(3,minmax(0,1fr))">
        {#each cards as card}<Link href={card.path} class="list-row" style="min-height:72px"><span class="grow col"><strong>{card.title}</strong><span class="faint">{card.description}</span></span><span class="data">→</span></Link>{/each}
      </div>
    </section>
  </section>

{:else if view === "report_form"}
  <section class="screen">
    {#if description}<p class="screen-description">{description}</p>{/if}
    <form id="report-form" class="p-region" onsubmit={generateReport}>
      <PanelHeader title="Report parameters" count={`${form.parameters.length} fields`} />
      <div class="form-grid form-grid-2">
        {#each form.parameters as parameter}
          <div class="k-field"><label class="k-label" for={parameter.key}>{parameter.label}{#if parameter.required} <span class="k-req">*</span>{/if}</label>{#if parameter.type === "select"}<select class="k-input" id={parameter.key} required={parameter.required} bind:value={reportValues[parameter.key]}>{#each parameter.options || [] as option}<option value={Array.isArray(option) ? option[1] : option.value}>{Array.isArray(option) ? option[0] : option.label}</option>{/each}</select>{:else}<input class:k-input-data={parameter.type !== "text"} class="k-input" id={parameter.key} type={parameter.type === "integer" ? "number" : parameter.type} required={parameter.required} bind:value={reportValues[parameter.key]} />{/if}</div>
        {/each}
      </div>
      <footer class="p-foot"><span>Generate the report from the command bar.</span></footer>
    </form>
  </section>

{:else if view === "report_show"}
  <section class="screen">
    <div class={`n-bar n-${stateTone(report.status)}`}><StatusTag value={report.status} /><span>Generated {report.created_at}.</span><span class="n-bar-actions">{#if report.status === "completed"}<a href={actions.pdf} class="k-btn k-btn-xs">Export PDF</a>{/if}<Link href={actions.index} class="k-btn k-btn-xs k-btn-quiet">All reports</Link></span></div>
    {#if ["pending", "processing"].includes(report.status)}<div class="n-bar n-live"><strong>{report.status === "pending" ? "Report queued." : "Report running."}</strong> Results will appear when processing finishes.</div>
    {:else if report.status === "failed"}<div class="n-bar n-bad"><strong>Report generation failed.</strong> {report.error_message}</div>{/if}

    {#if report.status === "completed"}
      <Deferred data="report.result_data">
        {#snippet fallback()}<div class="m-strip" style="grid-template-columns:minmax(0,1fr)"><div class="m-cell" aria-busy="true"><p class="m-label">Report results</p><p class="m-note">Loading the generated dataset…</p></div></div>{/snippet}
        {#snippet rescue()}<div class="n-bar n-bad"><strong>Report results unavailable.</strong> Reload this page to retry.</div>{/snippet}
        {#if report.result_data?.summary}<div class="m-strip" style={`grid-template-columns:repeat(${Math.min(Object.keys(report.result_data.summary).length,6)},minmax(0,1fr))`}>{#each Object.entries(report.result_data.summary) as [key, value]}<div class="m-cell"><p class="m-label">{key.replaceAll("_", " ")}</p><p class="m-value">{value}</p></div>{/each}</div>{/if}
      </Deferred>
    {/if}

    <div class="p-split" style="grid-template-columns:minmax(0,1fr) 280px">
      {#if report.status === "completed"}
        <Deferred data="report.result_data">
          {#snippet fallback()}<DeferredPanel title="Report detail" message="Loading chart and table data…" />{/snippet}
          {#snippet rescue()}<section class="p-region"><EmptyState title="Results unavailable" body="Reload this page to retry the report data request." /></section>{/snippet}
          <section class="p-region">
            {#if report.result_data?.chart}
              <PanelHeader title="Chart" count={`${report.result_data.chart.labels?.length || 0} points`} />
              <div class="p-body" style="overflow:visible"><div class="chart-bars">{#each report.result_data.chart.labels || [] as label, index}<div class="chart-bar"><span class="chart-bar-value">{report.result_data.chart.datasets?.[0]?.data?.[index] ?? 0}</span><div class="chart-bar-fill" style={`height:${chartHeight(report.result_data.chart.datasets?.[0]?.data?.[index], report.result_data.chart.datasets?.[0]?.data || [])}`}></div><span class="chart-bar-label">{label}</span></div>{/each}</div></div>
            {/if}
            <PanelHeader title="Report detail" count={`${report.result_data?.table?.length || 0} records`} />
            {#if report.result_data?.table?.length}<div class="t-wrap"><table class="t" style="min-width:780px"><thead><tr>{#each report.table_columns as column}<th>{column.label}</th>{/each}</tr></thead><tbody>{#each report.result_data.table as row}<tr data-state="idle">{#each report.table_columns as column}<td class:data={machineField(column.key, column.label)}>{displayValue(row[column.key])}</td>{/each}</tr>{/each}</tbody></table></div>{:else}<EmptyState title="No detail rows" body="This report completed without tabular results." />{/if}
          </section>
        </Deferred>
      {:else}
        <section class="p-region"><EmptyState title="Results not ready" body="Generated report data will appear here." /></section>
      {/if}
      <aside class="p-region">
        <PanelHeader title="Parameters" />
        <dl class="d-grid">{#each Object.entries(report.parameters || {}) as [key, value]}<div class="d-row"><dt>{key.replaceAll("_", " ")}</dt><dd class:data={machineField(key, key)}>{displayValue(value)}</dd></div>{/each}</dl>
        <div class="p-body" style="margin-top:auto"><button class="k-btn k-btn-danger" type="button" onclick={() => (showReportDelete = true)}>Delete report</button></div>
      </aside>
    </div>
  </section>

{:else if view === "gift_certificate_show"}
  <section class="screen">
    <div class="p-split" style="grid-template-columns:minmax(320px,0.8fr) minmax(0,1.2fr)">
      <section class="p-region">
        <PanelHeader title="Certificate" count={certificate.code}><Link href={actions.index} class="k-btn k-btn-xs k-btn-quiet">All certificates</Link></PanelHeader>
        <div class="p-body"><article id="gift-certificate-print" class="receipt-sheet" style="text-align:center;border-color:var(--color-accent)"><p class="k-label">{store?.name || "EI Point of Sale"}</p><p style="margin-top:var(--space-6);font-size:var(--text-strong);font-weight:var(--weight-semibold)">Gift certificate</p><p class="data" style="margin-top:var(--space-6);font-size:var(--text-readout)">{certificate.code}</p><p style="margin-top:var(--space-4)">Current balance</p><p class="r-out-value">{certificate.remaining_balance}</p></article></div>
      </section>
      <section class="p-region">
        <PanelHeader title="Certificate details" />
        <dl class="d-grid" style="grid-template-columns:repeat(2,minmax(0,1fr))">{#each Object.entries(certificate) as [key, value]}<div class="d-row"><dt>{key.replaceAll("_", " ")}</dt><dd class:data={machineField(key, key)}>{displayValue(value)}</dd></div>{/each}</dl>
        <PanelHeader title="Redemption history" count={redemptions.length} />
        <div class="t-wrap"><table class="t" style="min-width:620px"><thead><tr><th>Order</th><th class="r">Amount</th><th>Received by</th><th>Date</th></tr></thead><tbody>{#each redemptions as redemption}<tr data-state="ok"><td><Link href={redemption.order_path} class="data">{redemption.order}</Link></td><td class="r data">{redemption.amount}</td><td>{redemption.received_by}</td><td class="data">{redemption.created_at}</td></tr>{:else}<tr><td colspan="4"><EmptyState title="No redemptions" body="Uses of this certificate will appear here." /></td></tr>{/each}</tbody></table></div>
      </section>
    </div>
  </section>

{:else if view === "receipt_template_show"}
  <section class="screen">
    <div class="p-split" style="grid-template-columns:minmax(0,1fr) minmax(340px,0.8fr)">
      <section class="p-region"><PanelHeader title="Template details" count={`${details.length} fields`}><Link href={actions.index} class="k-btn k-btn-xs k-btn-quiet">All templates</Link><Link href={actions.edit} class="k-btn k-btn-xs">Edit</Link>{#if actions.activate}<button class="k-btn k-btn-xs" type="button" onclick={() => router.patch(actions.activate)}>Activate</button>{/if}</PanelHeader><dl class="d-grid" style="grid-template-columns:repeat(2,minmax(0,1fr))">{#each details as detail}<div class="d-row"><dt>{detail.label}</dt><dd>{displayValue(detail.value)}</dd></div>{/each}</dl></section>
      <section class="p-region"><PanelHeader title="Print preview" count={`${preview_lines.length} lines`} /><pre class="receipt-sheet" style="white-space:pre;overflow:auto">{preview_lines.join("\n")}</pre></section>
    </div>
  </section>

{:else if view === "backups"}
  <section class="screen">
    <Deferred data={["status", "details", "files", "actions"]}>
      {#snippet fallback()}<div class="p-split" style="grid-template-columns:repeat(2,minmax(0,1fr))"><DeferredPanel title="Database backups" message="Connecting to Google Drive…" /><DeferredPanel title="Garage bucket backups" message="Loading available files…" /></div>{/snippet}
      {#snippet rescue()}<section class="p-region"><EmptyState title="Backups unavailable" body="Google Drive could not be reached. Reload this page to retry." /></section>{/snippet}
      <div class={`n-bar n-${stateTone(status)}`}><StatusTag value={status} />{#each details as detail}<span><strong>{detail.label}</strong> {detail.value}</span>{/each}<span class="n-bar-actions">{#each actions as item}<button class="k-btn k-btn-xs" type="button" onclick={() => perform(item)}>{item.label}</button>{/each}</span></div>
      <div class="p-split" style={`grid-template-columns:repeat(${Math.max(files.length,1)},minmax(0,1fr))`}>{#each files as group}<section class="p-region"><PanelHeader title={group.label} count={group.items.length} /><div class="t-wrap"><table class="t" style="min-width:520px"><thead><tr><th>File</th><th>Date</th><th class="r">Size</th><th></th></tr></thead><tbody>{#each group.items as item}<tr data-state="ok"><td class="data">{item.name}</td><td class="data">{item.created_at}</td><td class="r data">{item.size}</td><td class="r"><a href={item.path} class="k-btn k-btn-xs k-btn-quiet">Download</a></td></tr>{:else}<tr><td colspan="4"><EmptyState title="No backups" body="Connected backup files will appear here." /></td></tr>{/each}</tbody></table></div></section>{/each}</div>
    </Deferred>
  </section>

{:else if view === "recurring_tasks"}
  <section class="screen"><section class="p-region"><PanelHeader title="Recurring tasks" count={recurring_tasks.length} /><div class="t-wrap"><table class="t" style="min-width:860px"><thead><tr><th>Task</th><th>Schedule</th><th>Job</th><th>Last run</th><th>State</th><th></th></tr></thead><tbody>{#each recurring_tasks as item}<tr data-state={stateTone(item.last_job_status)}><td class="data">{item.key}</td><td class="data">{item.schedule}</td><td class="data">{item.class_name}</td><td class="data">{item.last_run_at || "Never"}</td><td><StatusTag value={item.last_job_status} /></td><td class="r"><button class="k-btn k-btn-xs" type="button" onclick={() => router.post(item.run_path)}>Run now</button></td></tr>{:else}<tr><td colspan="6"><EmptyState title="No recurring tasks" body="Configured schedules will appear here." /></td></tr>{/each}</tbody></table></div></section></section>

{:else if view === "order_show"}
  <section class="screen">
    <div class={`n-bar n-${stateTone(order.status)}`}><StatusTag value={order.status} solid /><span>{order.customer?.name || "Quick sale"} · {order.total}</span><span class="n-bar-actions"><Link href={actions.index} class="k-btn k-btn-xs k-btn-quiet">Order history</Link>{#if ["draft", "held"].includes(order.status)}<Link href={actions.register} class="k-btn k-btn-xs">Open in register</Link>{/if}<Link href={actions.receipt} class="k-btn k-btn-xs">Receipt</Link>{#if ["completed", "partially_refunded"].includes(order.status)}<Link href={actions.refund} class="k-btn k-btn-xs k-btn-danger">Refund</Link>{/if}</span></div>
    <div class="p-split" style="grid-template-columns:minmax(0,1fr) 300px">
      <section class="p-region"><PanelHeader title="Line items" count={`${order.lines.length} lines`} /><div class="t-wrap"><table class="t" style="min-width:680px"><thead><tr><th>Item</th><th class="r">Qty</th><th class="r">Price</th><th class="r">Tax</th><th class="r">Total</th></tr></thead><tbody>{#each order.lines as line}<tr data-state="idle"><td class="wrap"><strong>{line.name}</strong><span class="t-sub data">{line.code || "—"}</span></td><td class="r data">{line.quantity}</td><td class="r data">{line.unit_price}</td><td class="r data">{line.tax}</td><td class="r data"><strong>{line.total}</strong></td></tr>{/each}</tbody></table></div></section>
      <aside class="p-region"><div class="r-out"><p class="r-out-label">Order total</p><p class="r-out-value">{order.total}</p></div><dl class="r-lines"><div class="r-line"><dt>Customer</dt><dd>{order.customer?.name || "Quick sale"}</dd></div><div class="r-line"><dt>Subtotal</dt><dd>{order.subtotal}</dd></div><div class="r-line"><dt>Tax</dt><dd>{order.tax_total}</dd></div><div class="r-line r-line-total"><dt>Total</dt><dd>{order.total}</dd></div></dl><Deferred data="events">{#snippet fallback()}<PanelHeader title="Activity" count="Loading…" /><div class="p-body faint" aria-busy="true">Loading order activity…</div>{/snippet}{#snippet rescue()}<PanelHeader title="Activity unavailable" /><div class="p-body faint">Reload to retry.</div>{/snippet}<PanelHeader title="Activity" count={events.length} /><div class="p-body-flush">{#each events as event}<div class="list-row" data-state={stateTone(event.type)}><span class="grow col"><strong>{event.type}</strong><span class="faint">{event.actor}</span></span><span class="data faint">{event.at}</span></div>{/each}</div></Deferred></aside>
    </div>
  </section>

{:else if view === "receipt"}
  <section class="screen"><section class="p-region"><PanelHeader title="Receipt preview" count={order.number}><Link href={actions.order} class="k-btn k-btn-xs k-btn-quiet">Back to order</Link></PanelHeader><div class="screen-scroll"><article class="receipt-sheet"><div style="text-align:center"><strong style="font-size:var(--text-strong)">{store?.name}</strong><p>{[store?.address_line1, store?.city, store?.province, store?.postal_code].filter(Boolean).join(", ")}</p><p>{store?.phone || ""}</p></div><div class="p-rule" style="margin:var(--space-4) 0"></div><p>{order.number} · {order.completed_at}</p><div style="margin:var(--space-4) 0">{#each order.lines as line}<div class="r-line" style="padding:2px 0"><span>{line.quantity} × {line.name}</span><span>{line.total}</span></div>{/each}</div><div class="p-rule" style="margin:var(--space-4) 0"></div><div class="r-line r-line-total"><strong>Total</strong><strong>{order.total}</strong></div>{#if receipt_lines.length}<pre style="margin-top:var(--space-4);white-space:pre-wrap">{receipt_lines.join("\n")}</pre>{/if}</article></div></section></section>

{:else if view === "refund"}
  <section class="screen"><form id="refund-form" class="p-region" onsubmit={requestRefund}><PanelHeader title="Refundable line items" count={`${selectedRefunds.length} selected`} /><div class="t-wrap"><table class="t" style="min-width:760px"><thead><tr><th class="c">Refund</th><th>Item</th><th class="r">Original</th><th class="r">Refund qty</th><th class="c">Restock</th><th class="r">Price</th></tr></thead><tbody>{#each order.lines as line, index}<tr data-state={refundLines[index].selected ? "warn" : "idle"} aria-selected={refundLines[index].selected}><td class="c"><input type="checkbox" aria-label={`Refund ${line.name}`} bind:checked={refundLines[index].selected} /></td><td>{line.name}</td><td class="r data">{line.quantity}</td><td class="r"><input class="k-input k-input-xs k-input-data" style="width:64px;text-align:right" aria-label={`Refund quantity for ${line.name}`} type="number" min="1" max={line.refundable_quantity ?? line.quantity} bind:value={refundLines[index].quantity} /></td><td class="c">{#if line.sellable_type === "Product"}<input type="checkbox" aria-label={`Restock ${line.name}`} bind:checked={refundLines[index].restock} />{:else}—{/if}</td><td class="r data">{line.unit_price}</td></tr>{/each}</tbody></table></div><div class="p-body"><div class="k-field"><label class="k-label" for="refund-reason">Reason</label><textarea id="refund-reason" class="k-input" rows="3" bind:value={refundReason}></textarea><p class="k-hint">The reason appears in the order audit history.</p></div></div></form></section>

{:else if view === "inventory"}
  <section class="screen">
    <form class="k-scan" style="border-top:0;border-bottom:1px solid var(--color-border)" onsubmit={lookupInventory}><label class="k-label" for="inventory-code">Product code</label><input id="inventory-code" class="k-input" placeholder="Scan or enter product code…" bind:value={inventoryCode} /><button class="k-btn k-btn-primary" style="height:36px">Add product <kbd>↵</kbd></button></form>
    <div class="p-split" style="grid-template-columns:minmax(0,1fr) 300px">
      <form id="inventory-form" class="p-region" onsubmit={commitInventory}><PanelHeader title="Restock batch" count={`${inventoryItems.length} products`} /><div class="t-wrap"><table class="t" style="min-width:720px"><thead><tr><th>Code</th><th>Product</th><th class="r">Current</th><th class="r">Add</th><th>Notes</th><th></th></tr></thead><tbody>{#each inventoryItems as item, index}<tr data-state="live"><td class="data">{item.code}</td><td>{item.name}</td><td class="r data">{item.stock_level}</td><td class="r"><input class="k-input k-input-xs k-input-data" style="width:64px;text-align:right" aria-label={`Quantity for ${item.name}`} type="number" min="1" bind:value={item.quantity} /></td><td><input class="k-input k-input-xs" aria-label={`Notes for ${item.name}`} bind:value={item.notes} /></td><td class="r"><button class="k-btn k-btn-xs k-btn-danger" type="button" aria-label={`Remove ${item.name}`} onclick={() => (inventoryItems = inventoryItems.filter((_, itemIndex) => itemIndex !== index))}>×</button></td></tr>{:else}<tr><td colspan="6"><EmptyState title="No products in this batch" body="Scan a product code to add a stock movement." /></td></tr>{/each}</tbody></table></div></form>
      <aside class="p-region"><PanelHeader title="CSV import" /><div class="p-body col" style="gap:var(--space-2)"><p class="console-prose">Use columns named code, quantity, and notes. The import commits stock movements immediately.</p><div class="k-field"><label class="k-label" for="inventory-file">CSV file</label><input id="inventory-file" class="k-input" type="file" accept=".csv" onchange={(event) => (inventoryFile = event.currentTarget.files?.[0])} /></div><button class="k-btn" type="button" onclick={importInventory}>Upload and restock</button></div></aside>
    </div>
  </section>

{:else if view === "cash_drawer"}
  <section class="screen"><div class="p-split" style="grid-template-columns:minmax(320px,0.8fr) minmax(0,1.2fr)"><section class="p-region"><PanelHeader title="Current drawer" count={session ? "Open" : "Closed"}><Link href={actions.history} class="k-btn k-btn-xs k-btn-quiet">History</Link></PanelHeader>{#if session}<div class="r-out r-out-settled"><p class="r-out-label">Opening float</p><p class="r-out-value">{session.opening_total}</p></div><dl class="d-grid"><div class="d-row"><dt>Opened</dt><dd class="data">{session.opened_at}</dd></div><div class="d-row"><dt>Opened by</dt><dd>{session.opened_by}</dd></div></dl><div class="p-body"><Link href={actions.close} class="k-key k-key-primary">Close register<span class="k-key-sub">Count and reconcile</span></Link></div>{:else}<EmptyState title="The register is closed" body={pending_reconciliation ? "Reconcile the terminal before opening the next drawer." : "Open the drawer before the first sale."} /><div class="p-body">{#if pending_reconciliation}<Link href={actions.reconcile} class="k-key k-key-primary">Reconcile terminal<span class="k-key-sub">Required</span></Link>{:else}<Link href={actions.open} class="k-key k-key-primary">Open register<span class="k-key-sub">Enter float</span></Link>{/if}</div>{/if}</section><section class="p-region"><PanelHeader title="Recent sessions" count={recent_sessions.length} /><div class="p-body-flush">{#each recent_sessions as item}<Link href={item.path} class="list-row" data-state="ok"><span class="grow data">{item.opened_at}</span><span class="data">{item.closing_total}</span></Link>{:else}<EmptyState title="No completed sessions" body="Closed drawer sessions will appear here." />{/each}</div></section></div></section>

{:else if view === "drawer_count"}
  <section class="screen"><form id="drawer-count-form" class="p-region" onsubmit={submitCount}><PanelHeader title="Denomination count" count={`${denominations.length} denominations`} /><div class="t-wrap"><table class="t" style="min-width:620px"><thead><tr><th>Denomination</th><th class="r">Count</th><th class="r">Line total</th></tr></thead><tbody>{#each denominations as item}<tr data-state="idle"><td>{item.label}</td><td class="r"><input class="k-input k-input-xs k-input-data" style="width:72px;text-align:right" type="number" min="0" bind:value={counts[item.key]} aria-label={`${item.label} count`} /></td><td class="r data">${(Number(counts[item.key] || 0) * item.value).toFixed(2)}</td></tr>{/each}</tbody><tfoot><tr><td>Grand total</td><td></td><td class="r data">${countTotal.toFixed(2)}</td></tr></tfoot></table></div><div class="p-body"><div class="k-field"><label class="k-label" for="drawer-notes">Notes</label><textarea id="drawer-notes" class="k-input" rows="3" bind:value={notes}></textarea></div></div></form></section>

{:else if view === "reconcile"}
  <section class="screen"><div class="m-strip" style="grid-template-columns:repeat(2,minmax(0,1fr))"><div class="m-cell"><p class="m-label">Expected debit</p><p class="m-value">{reconciliation.expected_debit_total}</p></div><div class="m-cell"><p class="m-label">Expected credit</p><p class="m-value">{reconciliation.expected_credit_total}</p></div></div><form id="reconcile-form" class="p-region" onsubmit={submitReconciliation}><PanelHeader title="Terminal totals" /><div class="form-grid form-grid-2"><div class="k-field"><label class="k-label" for="debit-total">Debit terminal total</label><input id="debit-total" class="k-input k-input-data" type="number" step="0.01" bind:value={reconcileValues.debit_total} /><p class="k-hint">Expected {reconciliation.expected_debit_total}</p></div><div class="k-field"><label class="k-label" for="credit-total">Credit terminal total</label><input id="credit-total" class="k-input k-input-data" type="number" step="0.01" bind:value={reconcileValues.credit_total} /><p class="k-hint">Expected {reconciliation.expected_credit_total}</p></div><div class="k-field field-wide"><label class="k-label" for="reconcile-notes">Notes</label><textarea id="reconcile-notes" class="k-input" rows="4" bind:value={reconcileValues.notes}></textarea></div></div></form></section>

{:else if view === "notifications"}
  <section class="screen"><div class="f-bar"><StatusTag value={`${unread_count} unread`} tone={unread_count ? "live" : "idle"} /><button class="k-btn k-btn-sm push" type="button" onclick={() => router.patch(actions.mark_all)}>Mark all read</button><button class="k-btn k-btn-sm k-btn-danger" type="button" onclick={() => router.delete(actions.clear_all)}>Clear all</button></div><section class="p-region"><PanelHeader title="Notifications" count={notifications.length} /><div class="p-body-flush">{#each notifications as notification}<article class="list-row" data-state={notification.read ? "idle" : "live"} style="align-items:flex-start"><span class="grow col"><strong>{notification.title}</strong><span class="muted">{notification.body}</span><span class="row">{#if notification.url}<Link href={notification.url} class="k-btn k-btn-xs k-btn-quiet">Open</Link>{/if}<button class="k-btn k-btn-xs k-btn-danger" type="button" onclick={() => router.delete(notification.path)}>Delete</button></span></span><span class="data faint">{notification.at}</span></article>{:else}<EmptyState title="No notifications" body="Operational alerts and completed background work will appear here." />{/each}</div></section></section>

{:else}
  <section class="screen">
    {#if errors.length}<div class="n-bar n-bad"><strong>{errors.length} issues need attention.</strong> {errors.join(" · ")}</div>{/if}
    <div class="f-bar">{#each actions as item}{#if !item.upload}<button class="k-btn k-btn-sm" type="button" onclick={() => perform(item)}>{item.label}</button>{/if}{/each}</div>
    {#if actions[0]?.upload}<form class="f-bar" onsubmit={submitOperationalUpload}><label class="k-label" for="operation-file">CSV file</label><input id="operation-file" class="k-input k-input-sm" style="width:min(420px,60vw)" type="file" accept=".csv" onchange={(event) => (uploadFile = event.currentTarget.files?.[0])} /><button class="k-btn k-btn-sm k-btn-primary">Preview import</button></form>{/if}
    <div class="p-split" style="grid-template-columns:minmax(0,1fr) minmax(280px,0.5fr)">
      <section class="p-region"><PanelHeader title="Operational details" count={pagination ? pagination.count : details.length} /><dl class="d-grid" style="grid-template-columns:repeat(2,minmax(0,1fr))">{#each details as detail}<div class="d-row"><dt>{detail.label}</dt><dd class:data={machineField(detail.label, detail.label)}>{displayValue(detail.value)}</dd></div>{:else}<EmptyState title="No additional details" body="Status information will appear here when it is available." />{/each}</dl>{#if pagination && pagination_path}<Pagination path={pagination_path} {query} {pagination} />{/if}</section>
      <section class="p-region"><PanelHeader title="Recent imports" count={recent_imports.length} /><div class="p-body-flush">{#each recent_imports as item}<Link href={item.path} class="list-row" data-state={stateTone(item.status)}><span class="grow col"><strong>{item.file_name}</strong><span class="data faint">{item.created_at}</span></span><StatusTag value={item.status} /></Link>{:else}<EmptyState title="No recent imports" body="Uploaded imports will appear here." />{/each}</div></section>
    </div>
  </section>
{/if}

{#if showReportDelete}<ConfirmModal title="Delete this report?" message="The generated report and its export files will be removed. This cannot be undone." confirmLabel="Delete report" danger oncancel={() => (showReportDelete = false)} onconfirm={removeReport} />{/if}
{#if showRefundPrompt}<ConfirmModal title="Process this refund?" message={`${selectedRefunds.length} line items will be refunded${selectedRefunds.filter((line) => line.restock).length ? ` and ${selectedRefunds.filter((line) => line.restock).length} stock movements will be restored` : ""}. The order and payment totals will be updated.`} confirmLabel="Process refund" danger oncancel={() => (showRefundPrompt = false)} onconfirm={submitRefund} />{/if}
