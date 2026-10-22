<script>
  import { router } from "@inertiajs/svelte"
  import { onMount } from "svelte"
  import { createLiveSearch } from "../../lib/live-search.js"
  import Search from "@lucide/svelte/icons/search"

  export let open = false
  export let onclose = () => {}

  let query = ""
  let results = []
  let loading = false
  let activeIndex = 0
  let lookup
  let wasOpen = false
  let error = ""
  let input

  onMount(() => {
    lookup = createLiveSearch({ url: "/search.json?limit=12", minLength: 0, onChange: (state) => {
      results = state.results
      loading = state.loading
      error = state.error
      activeIndex = 0
    } })
    return () => lookup.destroy()
  })

  $: if (open && !wasOpen) {
    wasOpen = true
    window.setTimeout(() => input?.focus(), 0)
    search()
  } else if (!open && wasOpen) {
    wasOpen = false
    lookup?.cancel()
    query = ""
    results = []
  }

  function search() { lookup?.search(query) }

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
          <div class="n-empty"><p class="n-empty-title">{error || "No results"}</p><p class="n-empty-body">Try a name, SKU, barcode, email, or order number.</p></div>
        {/each}
      {/if}
    </div>
  </div>
{/if}
