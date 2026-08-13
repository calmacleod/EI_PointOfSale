<script>
  import { router } from "@inertiajs/svelte"
  import Search from "@lucide/svelte/icons/search"

  export let open = false
  export let onclose = () => {}

  let query = ""
  let results = []
  let loading = false
  let activeIndex = 0
  let timer
  let input

  $: if (open) {
    window.setTimeout(() => input?.focus(), 0)
    if (!query && !results.length) search()
  }

  async function search() {
    if (timer) window.clearTimeout(timer)
    timer = window.setTimeout(async () => {
      loading = true
      try {
        const response = await fetch(`/search.json?q=${encodeURIComponent(query)}&limit=12`, { headers: { Accept: "application/json" } })
        results = (await response.json()).results || []
        activeIndex = 0
      } finally {
        loading = false
      }
    }, query ? 90 : 0)
  }

  function choose(result) {
    onclose()
    query = ""
    results = []
    router.visit(result.url)
  }

  function keyboard(event) {
    if (event.key === "Escape") onclose()
    if (event.key === "ArrowDown") { event.preventDefault(); activeIndex = Math.min(activeIndex + 1, results.length - 1) }
    if (event.key === "ArrowUp") { event.preventDefault(); activeIndex = Math.max(activeIndex - 1, 0) }
    if (event.key === "Enter" && results[activeIndex]) { event.preventDefault(); choose(results[activeIndex]) }
  }
</script>

{#if open}
  <button class="modal-scrim" aria-label="Close search" onclick={onclose}></button>
  <div class="popover search-popover" role="dialog" aria-modal="true" aria-label="Global search" tabindex="-1">
    <label class="k-scan" style="border-top:0">
      <Search />
      <span class="sr-only">Search products, orders, and customers</span>
      <input bind:this={input} class="k-input" placeholder="Search products, orders, customers…" bind:value={query} oninput={search} onkeydown={keyboard} />
      <kbd>Esc</kbd>
    </label>
    <div class="search-results">
      {#if loading}
        <div class="n-empty"><p class="n-empty-title">Searching</p><p class="n-empty-body">Checking the live catalogue.</p></div>
      {:else}
        {#each results as result, index}
          <button type="button" class="list-row" aria-current={index === activeIndex ? "true" : undefined} onclick={() => choose(result)}>
            <span class="s-tag s-live">{result.type}</span>
            <span class="grow col"><strong>{result.label}</strong>{#if result.sublabel}<span class="faint">{result.sublabel}</span>{/if}</span>
            <kbd>↵</kbd>
          </button>
        {:else}
          <div class="n-empty"><p class="n-empty-title">No results</p><p class="n-empty-body">Try a name, SKU, barcode, email, or order number.</p></div>
        {/each}
      {/if}
    </div>
  </div>
{/if}
