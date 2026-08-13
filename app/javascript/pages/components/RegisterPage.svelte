<script>
  import { Link, router } from "@inertiajs/svelte"
  import { onMount } from "svelte"
  import ConfirmModal from "./ConfirmModal.svelte"
  import EmptyState from "./EmptyState.svelte"
  import PanelHeader from "./PanelHeader.svelte"
  import StatusTag from "./StatusTag.svelte"

  export let order
  export let active_orders = []
  export let held_count = 0
  export let actions = {}
  export let flash = {}

  let code = ""
  let notes = order?.notes || ""
  let payment = freshPayment(order)
  let customerQuery = ""
  let customers = []
  let customerLoading = false
  let discount = { name: "", discount_type: "percentage", value: "" }
  let giftCertificate = { initial_amount: "", customer_id: "" }
  let showCancelPrompt = false
  let showCompletePrompt = false
  let previousOrderId = order?.id
  let previousBalance = order?.balance_due_value

  onMount(() => {
    const chooseFromKey = (event) => chooseTender(event.detail)
    window.addEventListener("console:tender", chooseFromKey)
    return () => window.removeEventListener("console:tender", chooseFromKey)
  })

  $: if (order?.id !== previousOrderId) {
    previousOrderId = order?.id
    previousBalance = order?.balance_due_value
    notes = order?.notes || ""
    payment = freshPayment(order)
    customerQuery = ""
    customers = []
    showCancelPrompt = false
    showCompletePrompt = false
  }

  $: if (order?.balance_due_value !== previousBalance) {
    if (!payment.amount || Number(payment.amount) === Number(previousBalance)) payment.amount = order?.balance_due_value || ""
    previousBalance = order?.balance_due_value
  }

  $: canComplete = Boolean(order?.payment_complete && order?.lines?.length && order?.status === "draft")
  $: lineUnits = (order?.lines || []).reduce((sum, line) => sum + Number(line.quantity || 0), 0)

  function freshPayment(currentOrder) {
    return { payment_method: "cash", amount: currentOrder?.balance_due_value || "", amount_tendered: "", reference: "" }
  }

  function chooseTender(method) {
    payment = { ...payment, payment_method: method, amount: order?.balance_due_value || payment.amount }
    window.setTimeout(() => document.getElementById("payment-amount")?.focus(), 0)
  }

  function addCode(event) {
    event.preventDefault()
    if (!code.trim() || order.status !== "draft") return
    router.post(actions.quick_lookup, { order_id: order.id, code: code.trim() }, { preserveScroll: true, onSuccess: () => (code = "") })
  }

  function updateQuantity(line, quantity) {
    if (Number(quantity) > 0) router.patch(line.update_path, { order_line: { quantity: Number(quantity) } }, { preserveScroll: true })
  }
  function removeLine(line) { router.delete(line.delete_path, { preserveScroll: true }) }
  function updateDiscountQuantity(item, quantity) { router.patch(item.update_path, { order_line_discount: { applied_quantity: Number(quantity) } }, { preserveScroll: true }) }
  function updateOrder() { router.patch(actions.update, { order: { notes } }, { preserveScroll: true }) }
  function addPayment(event) {
    event.preventDefault()
    router.post(actions.payment, { order_payment: payment }, {
      preserveScroll: true,
      onSuccess: (page) => {
        const updatedOrder = page.props.order
        payment = freshPayment(updatedOrder)
        if (updatedOrder?.payment_complete && updatedOrder?.lines?.length) showCompletePrompt = true
      },
    })
  }
  function removePayment(item) { router.delete(item.path, { preserveScroll: true }) }
  function cancelOrder() { showCancelPrompt = false; router.delete(actions.cancel) }
  function completeOrder() { showCompletePrompt = false; router.post(actions.complete) }
  function addDiscount(event) {
    event.preventDefault()
    router.post(actions.discount, { order_discount: discount }, { preserveScroll: true, onSuccess: () => (discount = { name: "", discount_type: "percentage", value: "" }) })
  }
  function removeDiscount(item) { router.delete(item.path, { preserveScroll: true }) }
  function issueGiftCertificate(event) {
    event.preventDefault()
    router.post(actions.gift_certificate, { gift_certificate: giftCertificate }, { preserveScroll: true, onSuccess: () => (giftCertificate = { initial_amount: "", customer_id: "" }) })
  }
  async function searchCustomers() {
    if (customerQuery.trim().length < 2) { customers = []; return }
    customerLoading = true
    try {
      const response = await fetch(`${actions.customer_search}?q=${encodeURIComponent(customerQuery)}&format=json`, { headers: { Accept: "application/json" } })
      customers = (await response.json()).results || []
    } finally { customerLoading = false }
  }
  function assignCustomer(customer) { router.patch(actions.assign_customer, { customer_id: customer.id }); customers = []; customerQuery = "" }
</script>

<section class="screen" data-density="roomy">
  <div class="f-bar" style="background:var(--color-surface-alt)">
    <span class="p-title">Orders open</span>
    {#each active_orders as tab}
      <Link href={tab.register_path} class={`k-btn k-btn-sm data ${tab.id === order.id ? "k-btn-primary" : ""}`} aria-pressed={tab.id === order.id} data-order-id={tab.id} data-active-order={tab.id === order.id}>{tab.number} · {tab.line_count}</Link>
    {/each}
    <button class="k-btn k-btn-sm k-btn-quiet" type="button" onclick={() => router.post(actions.new_order)}>New order <kbd>F2</kbd></button>
    {#if held_count}<Link href={actions.held} class="push"><StatusTag value={`${held_count} held`} tone="warn" /></Link>{/if}
  </div>

  <div class="p-split" style="grid-template-columns:minmax(0,1fr) 360px">
    <section class="p-region">
      <PanelHeader title="Line items" count={`${order.lines.length} lines · ${lineUnits} units`}>
        <StatusTag value={order.status} solid />
        {#if order.status === "draft"}<button class="k-btn k-btn-xs k-btn-danger" type="button" onclick={() => (showCancelPrompt = true)}>Void order</button>{/if}
      </PanelHeader>
      <div id="order_line_items" class="t-wrap">
        {#if order.lines.length}
          <table class="t" style="min-width:720px">
            <thead><tr><th style="min-width:260px">Item</th><th class="c">Qty</th><th class="r">Unit</th><th class="r">Discount</th><th class="r">Line total</th><th></th></tr></thead>
            <tbody>
              {#each order.lines as line}
                <tr id={`order_line_${line.id}`} data-state={line.discounts.length ? "ok" : "idle"}>
                  <td class="wrap"><strong>{line.name}</strong><span class="t-sub data">{line.code || "—"}</span>{#each line.discounts as item}<span class="t-sub" style="color:var(--state-ok)">{item.name} · {item.display_value} · -{item.amount}{#if item.auto_applied && order.status === "draft"} · apply <input class="k-input k-input-xs k-input-data" style="width:45px;text-align:center" type="number" min="0" max={line.quantity} value={item.applied_quantity} aria-label={`Discount quantity for ${line.name}`} onchange={(event) => updateDiscountQuantity(item, event.currentTarget.value)} /> of {line.quantity}{/if}</span>{/each}</td>
                  <td class="c"><input class="k-input k-input-xs k-input-data" style="width:52px;text-align:center" aria-label={`Quantity for ${line.name}`} type="number" min="1" value={line.quantity} disabled={order.status !== "draft"} onchange={(event) => updateQuantity(line, event.currentTarget.value)} /></td>
                  <td class="r data">{line.unit_price}</td><td class="r data" style="color:var(--state-ok)">{line.discount || "—"}</td><td class="r data"><strong>{line.total}</strong></td>
                  <td class="r">{#if order.status === "draft"}<button class="k-btn k-btn-xs k-btn-danger" type="button" aria-label={`Remove ${line.name}`} onclick={() => removeLine(line)}>×</button>{/if}</td>
                </tr>
              {/each}
            </tbody>
          </table>
        {:else}<EmptyState title="No items yet" body="Scan a barcode or type a product or service code to begin." />{/if}
      </div>
      {#if flash.alert || flash.notice}<div id="lookup_flash" class={`n-bar ${flash.alert ? "n-bad" : "n-ok"}`}>{flash.alert || flash.notice}</div>{/if}
      <form class="k-scan" onsubmit={addCode}>
        <label class="sr-only" for="code">Scan barcode or enter product or service code</label>
        <input id="code" name="code" class="k-input" placeholder="Scan or type code…" disabled={order.status !== "draft"} bind:value={code} />
        <button class="k-btn k-btn-primary" style="height:36px" type="submit" disabled={order.status !== "draft"}>Add <kbd>↵</kbd></button>
      </form>
    </section>

    <aside class="p-region">
      <div class={`r-out ${order.payment_complete ? "r-out-settled" : "r-out-due"}`}><p class="r-out-label">{order.payment_complete ? "Payment settled" : "Balance due"}</p><p class="r-out-value">{order.balance_due}</p></div>
      <div class="grow p-region-scroll">
        <dl id="order_totals" class="r-lines" style="padding:var(--space-1-5) 0">
          <div class="r-line"><dt>Subtotal</dt><dd>{order.subtotal}</dd></div>
          <div class="r-line r-line-credit"><dt>Discounts</dt><dd>-{order.discount_total}</dd></div>
          <div class="r-line"><dt>Tax</dt><dd>{order.tax_total}</dd></div>
          <div class="r-line r-line-total"><dt>Total</dt><dd>{order.total}</dd></div>
          <div class="r-line"><dt>Paid</dt><dd>{order.amount_paid}</dd></div>
        </dl>

        <section id="order_payments_panel">
        <PanelHeader title="Tender" count={`${order.payments.length} payments`} />
        {#if order.status === "draft"}
          <div class="p-body" style="overflow:visible">
            <div class="k-keypad" style="grid-template-columns:repeat(4,1fr)">
              <button class="k-key" class:k-key-primary={payment.payment_method === "cash"} type="button" onclick={() => chooseTender("cash")}>Cash<span class="k-key-sub">F4</span></button>
              <button class="k-key" class:k-key-primary={payment.payment_method === "debit"} type="button" onclick={() => chooseTender("debit")}>Debit<span class="k-key-sub">F5</span></button>
              <button class="k-key" class:k-key-primary={payment.payment_method === "credit"} type="button" onclick={() => chooseTender("credit")}>Credit<span class="k-key-sub">F6</span></button>
              <button class="k-key" class:k-key-primary={payment.payment_method === "gift_certificate"} type="button" onclick={() => chooseTender("gift_certificate")}>Gift<span class="k-key-sub">F7</span></button>
            </div>
            <form class="col" style="gap:var(--space-1-5);margin-top:var(--space-2)" onsubmit={addPayment}>
              <div class="row"><label class="k-label" for="payment-amount">Amount</label><input id="payment-amount" class="k-input k-input-data" type="number" min="0" step="0.01" required bind:value={payment.amount} /></div>
              {#if payment.payment_method === "cash"}<div class="row"><label class="k-label" for="payment-tendered">Tendered</label><input id="payment-tendered" class="k-input k-input-data" type="number" min="0" step="0.01" bind:value={payment.amount_tendered} /></div>{/if}
              {#if ["gift_certificate", "other"].includes(payment.payment_method)}<div class="row"><label class="k-label" for="payment-reference">Reference</label><input id="payment-reference" class="k-input k-input-data" bind:value={payment.reference} /></div>{/if}
              <button class="k-btn k-btn-primary k-btn-block" type="submit">Take payment</button>
            </form>
          </div>
        {/if}
        {#each order.payments as item}<div class="list-row" data-state="ok" data-payment-id={item.id}><span class="grow col"><strong>{item.method}</strong><span class="faint data">{item.reference || (item.tendered ? `Tendered ${item.tendered} · change ${item.change}` : "Recorded")}</span></span><span class="data">{item.amount}</span>{#if order.status === "draft"}<button class="k-btn k-btn-xs k-btn-danger" type="button" aria-label={`Remove ${item.method} payment`} onclick={() => removePayment(item)}>×</button>{/if}</div>{/each}
        </section>

        <section id="order_customer_panel">
        <PanelHeader title="Customer" count={order.customer ? "Assigned" : "Quick sale"}>{#if order.customer && order.status === "draft"}<button class="k-btn k-btn-xs k-btn-danger" type="button" onclick={() => router.delete(actions.remove_customer)}>Remove</button>{/if}</PanelHeader>
        <div class="p-body" style="overflow:visible">
          {#if order.customer}<strong>{order.customer.name}</strong>{#if order.customer.alert}<div class="n-bar n-warn" style="margin:var(--space-2) calc(var(--space-3) * -1) calc(var(--space-3) * -1)">{order.customer.alert}</div>{/if}
          {:else if order.status === "draft"}<div class="k-field"><label class="k-label" for="customer-search">Find customer</label><input id="customer-search" class="k-input" placeholder="Name, email, or phone…" bind:value={customerQuery} oninput={searchCustomers} /></div>{#if customerLoading}<p class="k-hint">Searching live customers…</p>{/if}{#each customers as customer}<button class="list-row" style="width:100%" type="button" onclick={() => assignCustomer(customer)}><strong>{customer.name}</strong><span class="faint push">{customer.phone || customer.email}</span></button>{/each}
          {:else}<span class="faint">Quick sale</span>{/if}
        </div>
        </section>

        <section id="order_discounts_panel">
        <PanelHeader title="Discounts" count={order.discounts.length + order.line_discounts.length} />
        {#each order.discounts as item}<div class="list-row" data-state="ok"><span class="grow col"><strong>{item.name}</strong><span class="faint">{item.display_value} on all items</span></span><span class="data" style="color:var(--state-ok)">-{item.amount}</span>{#if order.status === "draft"}<button class="k-btn k-btn-xs k-btn-danger" type="button" aria-label={`Remove ${item.name}`} onclick={() => removeDiscount(item)}>×</button>{/if}</div>{/each}
        {#each order.line_discounts as item}<div class="list-row" data-state="ok"><span class="grow col"><strong>{item.name}</strong><span class="faint">{item.applied_quantity} of {item.total_quantity} units</span></span><span class="data" style="color:var(--state-ok)">-{item.amount}</span></div>{/each}
        {#if order.status === "draft"}<details class="p-body"><summary class="k-btn k-btn-sm">Add discount</summary><form class="form-grid form-grid-2" style="padding:var(--space-2) 0 0" onsubmit={addDiscount}><div class="k-field field-wide"><label class="k-label" for="discount-name">Discount name</label><input id="discount-name" class="k-input" required bind:value={discount.name} /></div><div class="k-field"><label class="k-label" for="discount-type">Type</label><select id="discount-type" class="k-input" bind:value={discount.discount_type}><option value="percentage">Percentage</option><option value="fixed_amount">Fixed total</option><option value="fixed_per_item">Fixed per item</option></select></div><div class="k-field"><label class="k-label" for="discount-value">Value</label><input id="discount-value" class="k-input k-input-data" type="number" min="0.01" step="0.01" required bind:value={discount.value} /></div><button class="k-btn field-wide" type="submit">Apply discount</button></form></details>{/if}
        </section>

        <PanelHeader title="Order options" />
        <div class="p-body col" style="gap:var(--space-2)">
          <label class="k-check"><input type="checkbox" checked={order.tax_exempt} disabled={order.status !== "draft"} onchange={(event) => router.patch(actions.update, { order: { tax_exempt: event.currentTarget.checked } })} />Tax exempt</label>
          <div class="k-field"><label class="k-label" for="order_notes">Notes</label><textarea id="order_notes" class="k-input" rows="3" disabled={order.status !== "draft"} bind:value={notes}></textarea></div>
          {#if order.status === "draft"}<button class="k-btn k-btn-sm" type="button" onclick={updateOrder}>Save notes</button>{/if}
          {#if order.status === "draft"}<details><summary class="k-btn k-btn-sm">Issue gift certificate</summary><form class="col" style="gap:var(--space-1-5);margin-top:var(--space-2)" onsubmit={issueGiftCertificate}><div class="k-field"><label class="k-label" for="gift-certificate-amount">Amount</label><input id="gift-certificate-amount" class="k-input k-input-data" type="number" min="0.01" step="0.01" required bind:value={giftCertificate.initial_amount} /></div><div class="k-field"><label class="k-label" for="gift-certificate-customer">Customer ID</label><input id="gift-certificate-customer" class="k-input k-input-data" type="number" bind:value={giftCertificate.customer_id} /></div><button class="k-btn" type="submit">Add certificate to order</button></form></details>{/if}
        </div>
      </div>

      <div style="flex-shrink:0;padding:var(--space-2);border-top:1px solid var(--color-border);display:grid;grid-template-columns:1fr 1fr;gap:var(--space-1-5)">
        {#if order.status === "draft"}<button class="k-key" type="button" onclick={() => router.post(actions.hold)}>Hold<span class="k-key-sub">F8</span></button>{:else if order.status === "held"}<button class="k-key" type="button" style="grid-column:1 / -1" onclick={() => router.post(actions.resume)}>Resume order<span class="k-key-sub">Return to till</span></button>{/if}
        {#if order.status === "draft"}<button id="complete_btn" class="k-key k-key-primary" type="button" disabled={!canComplete} onclick={() => (showCompletePrompt = true)}>Complete<span class="k-key-sub">F12</span></button>{/if}
      </div>
    </aside>
  </div>
</section>

{#if showCompletePrompt}<ConfirmModal id="complete_prompt_modal" title={`Complete ${order.number}?`} message={`Payment is complete. ${order.lines.length} line items will be finalized and inventory will be updated.`} confirmLabel="Complete order" oncancel={() => (showCompletePrompt = false)} onconfirm={completeOrder} />{/if}
{#if showCancelPrompt}<ConfirmModal id="void_prompt_modal" title={`Void ${order.number}?`} message={`${order.lines.length} line items, ${order.payments.length} payments, and ${order.discounts.length + order.line_discounts.length} discounts will be reversed. This cannot be undone.`} confirmLabel="Void order" danger oncancel={() => (showCancelPrompt = false)} onconfirm={cancelOrder} />{/if}
