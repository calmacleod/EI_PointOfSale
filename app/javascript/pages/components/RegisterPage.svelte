<script>
  import { Link, router } from "@inertiajs/svelte"

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
    if (!payment.amount || Number(payment.amount) === Number(previousBalance)) {
      payment.amount = order?.balance_due_value || ""
    }
    previousBalance = order?.balance_due_value
  }

  $: canComplete = Boolean(order?.payment_complete && order?.lines?.length && order?.status === "draft")

  function freshPayment(currentOrder) {
    return {
      payment_method: "cash",
      amount: currentOrder?.balance_due_value || "",
      amount_tendered: "",
      reference: "",
    }
  }

  function addCode(event) {
    event.preventDefault()
    if (!code.trim() || order.status !== "draft") return
    router.post(
      actions.quick_lookup,
      { order_id: order.id, code: code.trim() },
      { preserveScroll: true, onSuccess: () => (code = "") },
    )
  }

  function updateQuantity(line, quantity) {
    if (Number(quantity) > 0) {
      router.patch(line.update_path, { order_line: { quantity: Number(quantity) } }, { preserveScroll: true })
    }
  }

  function removeLine(line) {
    router.delete(line.delete_path, { preserveScroll: true })
  }

  function updateDiscountQuantity(item, quantity) {
    router.patch(
      item.update_path,
      { order_line_discount: { applied_quantity: Number(quantity) } },
      { preserveScroll: true },
    )
  }

  function updateOrder() {
    router.patch(actions.update, { order: { notes } }, { preserveScroll: true })
  }

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

  function removePayment(item) {
    router.delete(item.path, { preserveScroll: true })
  }

  function cancelOrder() {
    showCancelPrompt = false
    router.delete(actions.cancel)
  }

  function completeOrder() {
    showCompletePrompt = false
    router.post(actions.complete)
  }

  function addDiscount(event) {
    event.preventDefault()
    router.post(actions.discount, { order_discount: discount }, {
      preserveScroll: true,
      onSuccess: () => (discount = { name: "", discount_type: "percentage", value: "" }),
    })
  }

  function removeDiscount(item) {
    router.delete(item.path, { preserveScroll: true })
  }

  function issueGiftCertificate(event) {
    event.preventDefault()
    router.post(actions.gift_certificate, { gift_certificate: giftCertificate }, {
      preserveScroll: true,
      onSuccess: () => (giftCertificate = { initial_amount: "", customer_id: "" }),
    })
  }

  async function searchCustomers() {
    if (customerQuery.trim().length < 2) {
      customers = []
      return
    }

    customerLoading = true
    try {
      const response = await fetch(`${actions.customer_search}?q=${encodeURIComponent(customerQuery)}&format=json`, {
        headers: { Accept: "application/json" },
      })
      customers = (await response.json()).results || []
    } finally {
      customerLoading = false
    }
  }

  function assignCustomer(customer) {
    router.patch(actions.assign_customer, { customer_id: customer.id })
    customers = []
    customerQuery = ""
  }
</script>

<section class="-mx-3 -mt-4 sm:-mx-5 lg:-mx-7 lg:-mt-6">
  <div class="flex items-center gap-1 overflow-x-auto border-b px-3 py-2" style="border-color:var(--border);background:var(--surface-muted)">
    {#each active_orders as tab}
      <div data-order-id={tab.id} data-active-order={tab.id === order.id}>
        <Link href={tab.register_path} class="whitespace-nowrap rounded-lg px-3 py-1.5 text-xs font-semibold" style={`background:${tab.id === order.id ? "var(--primary)" : "var(--surface)"};color:${tab.id === order.id ? "var(--primary-foreground)" : "var(--foreground)"}`}>
          {tab.number} <span class="opacity-70">({tab.line_count})</span>
        </Link>
      </div>
    {/each}
    <button class="ui-button ui-button-secondary min-h-8!" type="button" onclick={() => router.post(actions.new_order)}>+ New</button>
    {#if held_count}<Link href={actions.held} class="ui-button ui-button-secondary min-h-8! ml-auto">Held <span class="ui-badge">{held_count}</span></Link>{/if}
  </div>

  <div class="flex items-center justify-between gap-3 border-b px-4 py-2" style="border-color:var(--border);background:var(--surface)">
    <div class="flex items-center gap-2"><h1 class="text-base font-semibold">{order.number}</h1><span class="ui-badge">{order.status}</span><span class="text-xs" style="color:var(--muted)">{order.created_by}</span></div>
    {#if order.status === "draft"}<button class="ui-button ui-button-danger min-h-8!" type="button" onclick={() => (showCancelPrompt = true)}>Cancel</button>{/if}
  </div>

  <div class="grid min-h-[calc(100vh-8rem)] xl:grid-cols-[minmax(0,1fr)_23rem]">
    <div class="flex min-w-0 flex-col border-r" style="border-color:var(--border)">
      <div class="flex-1 overflow-x-auto p-3 lg:p-4">
        <section id="order_line_items" class="ui-card min-h-64 overflow-hidden">
          {#if order.lines.length}
            <table class="ui-table">
              <thead><tr><th>Item</th><th class="w-24">Qty</th><th class="text-right">Price</th><th class="text-right">Discount</th><th class="text-right">Total</th><th class="w-12"></th></tr></thead>
              <tbody>
                {#each order.lines as line}
                  <tr id={`order_line_${line.id}`}>
                    <td>
                      <p class="font-medium">{line.name}</p><p class="text-xs" style="color:var(--muted)">{line.code}</p>
                      {#each line.discounts as item}
                        <div class="mt-2 rounded-lg border p-2 text-xs" style="border-color:var(--border);background:var(--surface-muted)">
                          <div class="flex items-center justify-between gap-2"><span><strong>{item.name}</strong> ({item.display_value})</span><span style="color:var(--success)">-{item.amount}</span></div>
                          {#if item.auto_applied && order.status === "draft"}
                            <label class="mt-1 flex items-center gap-2" style="color:var(--muted)">
                              Apply to
                              <input class="ui-input min-h-7! w-16! py-0! text-center" type="number" min="0" max={line.quantity} value={item.applied_quantity} data-discount-quantity-target="input" onchange={(event) => updateDiscountQuantity(item, event.currentTarget.value)} />
                              of {line.quantity}
                              {#if item.excluded_quantity >= line.quantity}<span style="color:var(--danger)">Excluded</span>{:else if item.excluded_quantity > 0}<span class="text-amber-700">Partial</span>{/if}
                            </label>
                          {/if}
                        </div>
                      {/each}
                    </td>
                    <td><input class="ui-input min-h-8! w-20! py-1! text-center" aria-label={`Quantity for ${line.name}`} type="number" min="1" value={line.quantity} disabled={order.status !== "draft"} onchange={(event) => updateQuantity(line, event.currentTarget.value)} /></td>
                    <td class="money text-right">{line.unit_price}</td><td class="money text-right">{line.discount}</td><td class="money text-right font-semibold">{line.total}</td>
                    <td>{#if order.status === "draft"}<button class="text-lg" type="button" style="color:var(--danger)" aria-label={`Remove ${line.name}`} onclick={() => removeLine(line)}>×</button>{/if}</td>
                  </tr>
                {/each}
              </tbody>
            </table>
          {:else}
            <div class="flex min-h-64 items-center justify-center p-12 text-center"><div><p class="font-medium">No items yet</p><p class="mt-1 text-xs" style="color:var(--muted)">Scan a barcode or enter an item code to begin.</p></div></div>
          {/if}
        </section>
      </div>
      <form class="border-t p-3" style="border-color:var(--border);background:var(--surface)" onsubmit={addCode}>
        <div class="flex gap-2"><label class="sr-only" for="code">Product or service code</label><input id="code" name="code" class="ui-input flex-1" placeholder="Scan barcode or enter SKU / service code" disabled={order.status !== "draft"} bind:value={code} /><button class="ui-button ui-button-primary" type="submit" disabled={order.status !== "draft"}>Add</button></div>
        <div id="lookup_flash" class="mt-1 min-h-4 text-xs" style={`color:${flash.alert ? "var(--danger)" : "var(--success)"}`}>{flash.alert || flash.notice || ""}</div>
      </form>
    </div>

    <aside class="space-y-3 p-3" style="background:var(--surface-muted)">
      <section id="order_customer_panel" class="ui-card overflow-hidden">
        <div class="ui-panel-header"><h2 class="text-sm font-semibold">Customer</h2>{#if order.customer && order.status === "draft"}<button class="text-xs font-semibold" type="button" style="color:var(--danger)" onclick={() => router.delete(actions.remove_customer)}>Remove</button>{/if}</div>
        <div class="p-3">
          {#if order.customer}
            <p class="text-sm font-semibold">{order.customer.name}</p>{#if order.customer.alert}<p class="mt-2 rounded-lg bg-amber-50 p-2 text-xs text-amber-900">{order.customer.alert}</p>{/if}
          {:else}
            <p class="mb-2 text-xs" style="color:var(--muted)">No customer</p>
            {#if order.status === "draft"}<label class="sr-only" for="customer-search">Search customer</label><input id="customer-search" class="ui-input" placeholder="Search customer by name, email, or phone" bind:value={customerQuery} oninput={searchCustomers} />{/if}
            {#if customerLoading}<p class="mt-2 text-xs">Searching…</p>{/if}
            {#each customers as customer}<button class="mt-1 block w-full rounded-lg border p-2 text-left text-sm" type="button" style="border-color:var(--border)" onclick={() => assignCustomer(customer)}><strong>{customer.name}</strong><span class="ml-2 text-xs" style="color:var(--muted)">{customer.phone || customer.email}</span></button>{/each}
          {/if}
        </div>
      </section>

      <section id="order_discounts_panel" class="ui-card overflow-hidden">
        <div class="ui-panel-header"><h2 class="text-sm font-semibold">Discounts</h2></div>
        <div class="space-y-2 p-3">
          {#each order.discounts as item}
            <div class="flex items-start justify-between gap-2 rounded-lg border p-2 text-xs" style="border-color:var(--border)">
              <div><p class="font-semibold">{item.name}{#if item.auto_applied} <span class="ui-badge">Auto</span>{/if}</p><p style="color:var(--muted)">{item.display_value} on all items</p></div>
              <div class="flex items-center gap-2"><span style="color:var(--success)">-{item.amount}</span>{#if order.status === "draft"}<button type="button" aria-label={`Remove ${item.name}`} style="color:var(--danger)" onclick={() => removeDiscount(item)}>×</button>{/if}</div>
            </div>
          {/each}
          {#each order.line_discounts as item}
            <div class="flex items-start justify-between gap-2 rounded-lg border p-2 text-xs" style="border-color:var(--border)"><div><p class="font-semibold">{item.name}{#if item.auto_applied} <span class="ui-badge">Auto</span>{/if}</p><p style="color:var(--muted)">{item.display_value} on {item.applied_quantity} of {item.total_quantity} units</p></div><span style="color:var(--success)">-{item.amount}</span></div>
          {/each}
          {#if !order.discounts.length && !order.line_discounts.length}<p class="text-xs" style="color:var(--muted)">No discounts applied.</p>{/if}
          {#if order.status === "draft"}
            <details><summary class="cursor-pointer text-xs font-semibold" style="color:var(--primary)">+ Add discount</summary><form class="mt-3 grid grid-cols-2 gap-2" onsubmit={addDiscount}><label class="sr-only" for="discount-name">Discount name</label><input id="discount-name" name="order_discount[name]" class="ui-input col-span-2" placeholder="Discount name" required bind:value={discount.name} /><label class="sr-only" for="discount-type">Discount type</label><select id="discount-type" name="order_discount[discount_type]" class="ui-input" bind:value={discount.discount_type}><option value="percentage">Percentage</option><option value="fixed_amount">Fixed Total</option><option value="fixed_per_item">Fixed Per Item</option></select><label class="sr-only" for="discount-value">Discount value</label><input id="discount-value" name="order_discount[value]" class="ui-input" type="number" min="0.01" step="0.01" required placeholder="Value" bind:value={discount.value} /><button class="ui-button ui-button-secondary col-span-2" type="submit">Apply discount</button></form></details>
          {/if}
        </div>
      </section>

      <section id="order_totals" class="ui-card overflow-hidden"><div class="ui-panel-header"><h2 class="text-sm font-semibold">Totals</h2></div><dl class="space-y-2 p-3 text-sm"><div class="flex justify-between"><dt>Subtotal</dt><dd class="money">{order.subtotal}</dd></div><div class="flex justify-between"><dt>Discounts</dt><dd class="money">-{order.discount_total}</dd></div><div class="flex justify-between"><dt>Tax</dt><dd class="money">{order.tax_total}</dd></div><div class="flex justify-between border-t pt-2 text-base font-semibold" style="border-color:var(--border)"><dt>Total</dt><dd class="money">{order.total}</dd></div><div class="flex justify-between"><dt>Paid</dt><dd class="money">{order.amount_paid}</dd></div><div class="flex justify-between"><dt>Balance due</dt><dd class="money font-semibold">{order.balance_due}</dd></div></dl></section>

      <section id="order_payments_panel" class="ui-card overflow-hidden">
        <div class="ui-panel-header"><h2 class="text-sm font-semibold">Payments</h2></div>
        <div class="p-3">
          {#each order.payments as item}<div class="mb-2 flex items-start justify-between text-sm" data-payment-id={item.id}><div><p>{item.method}{#if item.reference} <span class="text-xs" style="color:var(--muted)">({item.reference})</span>{/if}</p>{#if item.tendered}<p class="text-xs" style="color:var(--muted)">Tendered: {item.tendered} · Change: {item.change}</p>{/if}</div><span class="money ml-auto mr-2">{item.amount}</span>{#if order.status === "draft"}<button type="button" aria-label={`Remove ${item.method} payment`} style="color:var(--danger)" onclick={() => removePayment(item)}>×</button>{/if}</div>{/each}
          {#if order.status === "draft"}<form class="grid grid-cols-2 gap-2 border-t pt-3" style="border-color:var(--border)" onsubmit={addPayment}><label class="sr-only" for="payment-method">Payment method</label><select id="payment-method" name="order_payment[payment_method]" class="ui-input" bind:value={payment.payment_method}><option value="cash">Cash</option><option value="debit">Debit</option><option value="credit">Credit</option><option value="gift_certificate">Gift certificate</option><option value="other">Other</option></select><label class="sr-only" for="payment-amount">Payment amount</label><input id="payment-amount" name="order_payment[amount]" class="ui-input money" type="number" min="0" step="0.01" placeholder="Amount" required bind:value={payment.amount} />{#if payment.payment_method === "cash"}<label class="sr-only" for="payment-tendered">Amount tendered</label><input id="payment-tendered" name="order_payment[amount_tendered]" class="ui-input" type="number" min="0" step="0.01" placeholder="Tendered" bind:value={payment.amount_tendered} />{/if}{#if ["gift_certificate", "other"].includes(payment.payment_method)}<label class="sr-only" for="payment-reference">Reference</label><input id="payment-reference" name="order_payment[reference]" class="ui-input" placeholder="Reference" bind:value={payment.reference} />{/if}<button class="ui-button ui-button-primary col-span-2" type="submit">Add payment</button></form>{/if}
        </div>
      </section>

      {#if order.status === "draft"}<details class="ui-card p-3"><summary class="cursor-pointer text-sm font-semibold">Issue gift certificate</summary><form class="mt-3 grid grid-cols-2 gap-2" onsubmit={issueGiftCertificate}><label class="sr-only" for="gift-certificate-amount">Gift certificate amount</label><input id="gift-certificate-amount" name="gift_certificate[initial_amount]" class="ui-input" type="number" min="0.01" step="0.01" required placeholder="Amount" bind:value={giftCertificate.initial_amount} /><label class="sr-only" for="gift-certificate-customer">Customer ID</label><input id="gift-certificate-customer" name="gift_certificate[customer_id]" class="ui-input" type="number" placeholder="Customer ID (optional)" bind:value={giftCertificate.customer_id} /><button class="ui-button ui-button-secondary col-span-2" type="submit">Add to order</button></form></details>{/if}

      <section class="ui-card p-3"><label class="mb-3 flex items-center gap-2 text-sm font-medium"><input type="checkbox" checked={order.tax_exempt} disabled={order.status !== "draft"} onchange={(event) => router.patch(actions.update, { order: { tax_exempt: event.currentTarget.checked } })} />Tax exempt</label><label class="ui-label" for="order_notes">Notes</label><textarea id="order_notes" class="ui-input min-h-16" disabled={order.status !== "draft"} bind:value={notes}></textarea>{#if order.status === "draft"}<button class="ui-button ui-button-secondary mt-2 w-full" type="button" onclick={updateOrder}>Save notes</button>{/if}</section>

      <div class="grid grid-cols-2 gap-2">{#if order.status === "draft"}<button class="ui-button ui-button-secondary" type="button" onclick={() => router.post(actions.hold)}>Hold</button>{:else if order.status === "held"}<button class="ui-button ui-button-secondary col-span-2" type="button" onclick={() => router.post(actions.resume)}>Resume Order</button>{/if}{#if order.status === "draft"}<button id="complete_btn" class="ui-button ui-button-primary" type="button" disabled={!canComplete} onclick={() => (showCompletePrompt = true)}>Complete</button>{/if}</div>
    </aside>
  </div>
</section>

{#if showCompletePrompt}
  <div id="complete_prompt_modal" class="fixed inset-0 z-50 flex items-center justify-center bg-black/50 p-4" role="dialog" aria-modal="true" aria-labelledby="complete-prompt-title">
    <div class="ui-card w-full max-w-md p-5"><h2 id="complete-prompt-title" class="text-lg font-semibold">Complete {order.number}?</h2><p class="mt-2 text-sm" style="color:var(--muted)">Payment is complete. This will finalize the order and update inventory.</p><div class="mt-5 flex justify-end gap-2"><button class="ui-button ui-button-secondary" type="button" onclick={() => (showCompletePrompt = false)}>Keep editing</button><button class="ui-button ui-button-primary" type="button" onclick={completeOrder}>Complete Order</button></div></div>
  </div>
{/if}

{#if showCancelPrompt}
  <div class="fixed inset-0 z-50 flex items-center justify-center bg-black/50 p-4" role="dialog" aria-modal="true" aria-labelledby="cancel-prompt-title">
    <div class="ui-card w-full max-w-md p-5"><h2 id="cancel-prompt-title" class="text-lg font-semibold">Cancel {order.number}?</h2><p class="mt-2 text-sm" style="color:var(--muted)">All line items, payments, and discounts will be cancelled. This cannot be undone.</p><div class="mt-5 flex justify-end gap-2"><button class="ui-button ui-button-secondary" type="button" onclick={() => (showCancelPrompt = false)}>Keep Order</button><button class="ui-button ui-button-danger" type="button" onclick={cancelOrder}>Cancel Order</button></div></div>
  </div>
{/if}
