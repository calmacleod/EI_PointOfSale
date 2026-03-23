<script>
  import ProductCard from "./ProductCard.svelte"

  let { products = [], query = "", topN = 0 } = $props()
</script>

{#if !query && products.length > 0}
  <p class="mb-2 text-[11px] font-medium uppercase tracking-wider text-[#8e8e9a]">Top {topN} by sales</p>
{/if}

{#if products.length === 0}
  <div class="py-16 text-center">
    <svg class="mx-auto mb-3 h-8 w-8 text-[#c8c8c8]" fill="none" stroke="currentColor" viewBox="0 0 24 24">
      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="1.5" d="M20 7l-8-4-8 4m16 0l-8 4m8-4v10l-8 4m0-10L4 7m8 4v10M4 7v10l8 4"/>
    </svg>
    <p class="text-sm text-[#6b6b6b]">
      {#if query}
        No products found for <span class="font-medium text-[#1a1a1a]">"{query}"</span>
      {:else}
        No products cached yet — sync to load data
      {/if}
    </p>
  </div>
{:else}
  <div class="space-y-1.5">
    {#each products as product (product.id)}
      <ProductCard {product} />
    {/each}
  </div>
  {#if products.length === 50}
    <p class="mt-3 text-center text-xs text-[#6b6b6b]">Showing first 50 results — refine your search</p>
  {/if}
{/if}
