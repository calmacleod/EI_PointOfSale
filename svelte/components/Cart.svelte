<script>
  import { onMount, onDestroy } from "svelte"
  import { getAllTaxCodes } from "../lib/sync.js"
  import { bootWasm, seedTaxCodes, calculateOrderTotal, onWasmProgress } from "../lib/wasm.js"

  // --- State ---
  let lines = $state([])
  let totals = $state(null)
  let wasmStatus = $state("idle") // idle | booting | seeding | ready | error
  let wasmProgress = $state("")
  let wasmError = $state(null)
  let calculating = $state(false)

  // Item entry form
  let formName = $state("")
  let formPrice = $state("")
  let formQty = $state(1)
  let formTaxCodeId = $state("")
  let taxCodes = $state([])

  // --- WASM lifecycle ---
  const unsubProgress = onWasmProgress((step) => {
    wasmProgress = step
  })

  onMount(async () => {
    taxCodes = await getAllTaxCodes()
    if (taxCodes.length > 0) formTaxCodeId = String(taxCodes[0].id)
    await initWasm()
  })

  onDestroy(() => unsubProgress())

  async function initWasm() {
    wasmStatus = "booting"
    wasmError = null
    try {
      await bootWasm()
      wasmStatus = "seeding"
      wasmProgress = "Seeding tax codes into PGlite..."
      await seedTaxCodes(taxCodes.map((tc) => ({ id: tc.id, code: tc.code, name: tc.name, rate: tc.rate })))
      wasmStatus = "ready"
      wasmProgress = ""
    } catch (err) {
      wasmStatus = "error"
      wasmError = err.message
    }
  }

  // --- Cart logic ---
  async function addLine() {
    const name = formName.trim()
    const unit_price = parseFloat(formPrice)
    const quantity = parseInt(formQty, 10)
    const tax_code_id = formTaxCodeId ? parseInt(formTaxCodeId, 10) : null

    if (!name || isNaN(unit_price) || unit_price < 0 || isNaN(quantity) || quantity < 1) return

    lines = [...lines, { name, unit_price, quantity, tax_code_id }]
    formName = ""
    formPrice = ""
    formQty = 1
    await recalculate()
  }

  function removeLine(index) {
    lines = lines.filter((_, i) => i !== index)
    if (lines.length === 0) {
      totals = null
    } else {
      recalculate()
    }
  }

  async function recalculate() {
    if (wasmStatus !== "ready" || lines.length === 0) return
    calculating = true
    try {
      totals = await calculateOrderTotal(lines)
    } catch (err) {
      wasmError = err.message
    } finally {
      calculating = false
    }
  }

  function formatCurrency(n) {
    return (n ?? 0).toLocaleString("en-CA", { style: "currency", currency: "CAD" })
  }

  function formatRate(r) {
    return ((r ?? 0) * 100).toFixed(0) + "%"
  }

  const taxCodeLabel = $derived(
    (id) => taxCodes.find((tc) => tc.id === id)?.code ?? "—"
  )
</script>

<div class="cart-page">
  <!-- Header -->
  <div class="topbar">
    <div class="topbar-title">
      <svg class="topbar-icon" fill="none" stroke="currentColor" viewBox="0 0 24 24">
        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="1.75"
          d="M3 3h2l.4 2M7 13h10l4-8H5.4M7 13L5.4 5M7 13l-2.293 2.293c-.63.63-.184 1.707.707 1.707H17m0 0a2 2 0 100 4 2 2 0 000-4zm-8 2a2 2 0 11-4 0 2 2 0 014 0z" />
      </svg>
      <h1 class="topbar-heading">Order Calculator</h1>
    </div>

    <!-- WASM status badge -->
    <div class="wasm-badge" class:wasm-badge--ready={wasmStatus === "ready"} class:wasm-badge--error={wasmStatus === "error"} class:wasm-badge--booting={wasmStatus === "booting" || wasmStatus === "seeding"}>
      {#if wasmStatus === "ready"}
        <span class="badge-dot badge-dot--green"></span>
        Rails WASM ready
      {:else if wasmStatus === "error"}
        <span class="badge-dot badge-dot--red"></span>
        WASM error
      {:else if wasmStatus === "idle"}
        <span class="badge-dot badge-dot--gray"></span>
        WASM idle
      {:else}
        <span class="badge-dot badge-dot--yellow badge-dot--pulse"></span>
        {wasmProgress || "Booting Rails WASM…"}
      {/if}
    </div>
  </div>

  <div class="cart-body">
    <!-- Left: add item + line items -->
    <div class="cart-left">
      <!-- Add item form -->
      <div class="add-form card">
        <p class="card-title">Add item</p>

        <div class="form-row">
          <input
            class="input input--grow"
            type="text"
            placeholder="Item name"
            bind:value={formName}
            onkeydown={(e) => e.key === "Enter" && addLine()}
          />
        </div>
        <div class="form-row">
          <input
            class="input input--price"
            type="number"
            min="0"
            step="0.01"
            placeholder="Price"
            bind:value={formPrice}
          />
          <input
            class="input input--qty"
            type="number"
            min="1"
            placeholder="Qty"
            bind:value={formQty}
          />
          <select class="input input--tax" bind:value={formTaxCodeId}>
            <option value="">No tax</option>
            {#each taxCodes as tc}
              <option value={String(tc.id)}>{tc.code} ({formatRate(tc.rate)})</option>
            {/each}
          </select>
        </div>
        <button
          class="btn btn--primary"
          onclick={addLine}
          disabled={wasmStatus !== "ready"}
        >
          Add to order
        </button>
      </div>

      <!-- Line items -->
      {#if lines.length > 0}
        <div class="lines-list">
          {#each lines as line, i}
            <div class="line-card">
              <div class="line-main">
                <span class="line-name">{line.name}</span>
                <span class="line-meta">
                  {formatCurrency(line.unit_price)}
                  {#if line.quantity > 1}× {line.quantity}{/if}
                  {#if line.tax_code_id}
                    · {taxCodeLabel(line.tax_code_id)}
                  {/if}
                </span>
              </div>
              <div class="line-right">
                {#if totals?.lines?.[i]}
                  <span class="line-total">{formatCurrency(totals.lines[i].line_total)}</span>
                {:else}
                  <span class="line-total line-total--muted">{formatCurrency(line.unit_price * line.quantity)}</span>
                {/if}
                <button class="remove-btn" onclick={() => removeLine(i)} aria-label="Remove">
                  <svg fill="none" stroke="currentColor" viewBox="0 0 24 24" width="14" height="14">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" />
                  </svg>
                </button>
              </div>
            </div>
          {/each}
        </div>
      {:else}
        <div class="empty-state">
          <p>Add items above to calculate an order total.</p>
          <p class="empty-sub">Tax rates are looked up from PGlite running in Rails WASM.</p>
        </div>
      {/if}
    </div>

    <!-- Right: totals -->
    <div class="cart-right">
      <div class="totals-card card">
        <p class="card-title">
          Order totals
          {#if calculating}
            <span class="calculating">calculating…</span>
          {/if}
        </p>

        {#if totals}
          <div class="totals-rows">
            <div class="totals-row">
              <span>Subtotal</span>
              <span>{formatCurrency(totals.subtotal)}</span>
            </div>
            {#if totals.discount_total > 0}
              <div class="totals-row totals-row--discount">
                <span>Discount</span>
                <span>−{formatCurrency(totals.discount_total)}</span>
              </div>
            {/if}
            <div class="totals-row">
              <span>Tax</span>
              <span>{formatCurrency(totals.tax_total)}</span>
            </div>
            <div class="totals-row totals-row--total">
              <span>Total</span>
              <span>{formatCurrency(totals.total)}</span>
            </div>
          </div>
        {:else if lines.length > 0}
          <p class="totals-empty">Waiting for Rails WASM…</p>
        {:else}
          <p class="totals-empty">No items yet</p>
        {/if}
      </div>

      <!-- WASM info box -->
      <div class="info-box">
        <p class="info-title">About this page</p>
        <p class="info-body">
          Order totals are calculated by <strong>Rails business logic running in WebAssembly</strong>
          inside this browser tab — no server required. Tax rates are looked up from
          <strong>PGlite</strong> (in-browser Postgres), seeded from the local sync cache.
        </p>
        {#if wasmError}
          <p class="info-error">{wasmError}</p>
        {/if}
      </div>
    </div>
  </div>
</div>

<style>
  .cart-page {
    display: flex;
    flex-direction: column;
    flex: 1;
    min-width: 0;
    overflow: hidden;
  }

  /* Topbar */
  .topbar {
    display: flex;
    align-items: center;
    justify-content: space-between;
    flex-shrink: 0;
    border-bottom: 1px solid #c8c8c8;
    background: white;
    padding: 10px 16px;
  }

  .topbar-title {
    display: flex;
    align-items: center;
    gap: 8px;
  }

  .topbar-icon {
    width: 16px;
    height: 16px;
    color: #0d9488;
    flex-shrink: 0;
  }

  .topbar-heading {
    font-size: 14px;
    font-weight: 600;
    color: #1a1a2e;
    margin: 0;
  }

  /* WASM badge */
  .wasm-badge {
    display: flex;
    align-items: center;
    gap: 6px;
    padding: 4px 10px;
    border-radius: 9999px;
    font-size: 11px;
    font-weight: 500;
    border: 1px solid #e5e5e5;
    background: #f5f5f7;
    color: #555566;
  }

  .wasm-badge--ready {
    background: #f0fdf4;
    border-color: #bbf7d0;
    color: #166534;
  }

  .wasm-badge--error {
    background: #fef2f2;
    border-color: #fecaca;
    color: #991b1b;
  }

  .wasm-badge--booting {
    background: #fffbeb;
    border-color: #fde68a;
    color: #92400e;
  }

  .badge-dot {
    display: inline-block;
    width: 6px;
    height: 6px;
    border-radius: 50%;
    flex-shrink: 0;
  }

  .badge-dot--green { background: #22c55e; }
  .badge-dot--red   { background: #ef4444; }
  .badge-dot--gray  { background: #9ca3af; }
  .badge-dot--yellow { background: #f59e0b; }

  .badge-dot--pulse {
    animation: pulse 1.4s ease-in-out infinite;
  }

  @keyframes pulse {
    0%, 100% { opacity: 1; }
    50% { opacity: 0.3; }
  }

  /* Body layout */
  .cart-body {
    display: flex;
    flex: 1;
    min-height: 0;
    overflow: hidden;
    gap: 0;
  }

  .cart-left {
    flex: 1;
    min-width: 0;
    overflow-y: auto;
    padding: 16px;
    display: flex;
    flex-direction: column;
    gap: 12px;
  }

  .cart-right {
    width: 260px;
    flex-shrink: 0;
    border-left: 1px solid #c8c8c8;
    overflow-y: auto;
    padding: 16px;
    display: flex;
    flex-direction: column;
    gap: 12px;
    background: #f8f8fa;
  }

  /* Cards */
  .card {
    border: 1px solid #c8c8c8;
    border-radius: 8px;
    background: white;
    padding: 14px;
  }

  .card-title {
    margin: 0 0 10px;
    font-size: 12px;
    font-weight: 600;
    color: #555566;
    text-transform: uppercase;
    letter-spacing: 0.06em;
    display: flex;
    align-items: center;
    gap: 8px;
  }

  .calculating {
    font-size: 11px;
    font-weight: 400;
    color: #9ca3af;
    text-transform: none;
    letter-spacing: 0;
  }

  /* Add form */
  .add-form {
    flex-shrink: 0;
  }

  .form-row {
    display: flex;
    gap: 8px;
    margin-bottom: 8px;
  }

  .input {
    border: 1px solid #c8c8c8;
    border-radius: 6px;
    padding: 6px 10px;
    font-size: 13px;
    color: #1a1a2e;
    background: white;
    outline: none;
    transition: border-color 0.15s;
  }

  .input:focus {
    border-color: #0d9488;
  }

  .input--grow { flex: 1; min-width: 0; }
  .input--price { width: 90px; }
  .input--qty { width: 60px; }
  .input--tax { flex: 1; min-width: 0; }

  .btn {
    border: none;
    border-radius: 6px;
    padding: 7px 14px;
    font-size: 13px;
    font-weight: 500;
    cursor: pointer;
    transition: background 0.15s, opacity 0.15s;
  }

  .btn--primary {
    background: #0d9488;
    color: white;
    width: 100%;
  }

  .btn--primary:hover:not(:disabled) {
    background: #0f766e;
  }

  .btn--primary:disabled {
    opacity: 0.4;
    cursor: not-allowed;
  }

  /* Line items */
  .lines-list {
    display: flex;
    flex-direction: column;
    gap: 6px;
  }

  .line-card {
    display: flex;
    align-items: center;
    justify-content: space-between;
    border: 1px solid #e5e5e5;
    border-radius: 8px;
    background: white;
    padding: 10px 12px;
    gap: 12px;
  }

  .line-main {
    min-width: 0;
    flex: 1;
  }

  .line-name {
    display: block;
    font-size: 13px;
    font-weight: 500;
    color: #1a1a2e;
    white-space: nowrap;
    overflow: hidden;
    text-overflow: ellipsis;
  }

  .line-meta {
    font-size: 11px;
    color: #6b6b6b;
    margin-top: 1px;
  }

  .line-right {
    display: flex;
    align-items: center;
    gap: 10px;
    flex-shrink: 0;
  }

  .line-total {
    font-size: 13px;
    font-weight: 600;
    color: #1a1a2e;
  }

  .line-total--muted {
    color: #9ca3af;
  }

  .remove-btn {
    display: flex;
    align-items: center;
    justify-content: center;
    width: 22px;
    height: 22px;
    border: none;
    border-radius: 4px;
    background: transparent;
    color: #9ca3af;
    cursor: pointer;
    padding: 0;
    transition: background 0.1s, color 0.1s;
  }

  .remove-btn:hover {
    background: #fee2e2;
    color: #b91c1c;
  }

  /* Empty state */
  .empty-state {
    text-align: center;
    padding: 32px 16px;
    color: #6b6b6b;
    font-size: 13px;
    line-height: 1.6;
  }

  .empty-sub {
    margin-top: 6px;
    font-size: 11px;
    color: #9ca3af;
  }

  /* Totals */
  .totals-rows {
    display: flex;
    flex-direction: column;
    gap: 0;
  }

  .totals-row {
    display: flex;
    justify-content: space-between;
    align-items: center;
    padding: 6px 0;
    font-size: 13px;
    color: #555566;
    border-bottom: 1px solid #f0f0f0;
  }

  .totals-row:last-child {
    border-bottom: none;
  }

  .totals-row--discount {
    color: #059669;
  }

  .totals-row--total {
    font-size: 15px;
    font-weight: 700;
    color: #1a1a2e;
    margin-top: 2px;
    padding-top: 8px;
    border-top: 2px solid #e5e5e5;
  }

  .totals-empty {
    font-size: 12px;
    color: #9ca3af;
    margin: 0;
    padding: 8px 0;
  }

  /* Info box */
  .info-box {
    border: 1px solid #ddd6fe;
    border-radius: 8px;
    background: #f5f3ff;
    padding: 12px 14px;
  }

  .info-title {
    margin: 0 0 6px;
    font-size: 11px;
    font-weight: 600;
    color: #5b21b6;
    text-transform: uppercase;
    letter-spacing: 0.06em;
  }

  .info-body {
    margin: 0;
    font-size: 11px;
    color: #6d28d9;
    line-height: 1.6;
  }

  .info-error {
    margin: 8px 0 0;
    font-size: 11px;
    color: #991b1b;
    word-break: break-word;
  }
</style>
