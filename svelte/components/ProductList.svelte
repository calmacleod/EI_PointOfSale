<script>
  import ProductCard from "./ProductCard.svelte"

  let { products = [], query = "" } = $props()
</script>

{#if products.length === 0}
  <div class="py-12 text-center text-sm text-[var(--sidebar-text)] opacity-50">
    {#if query}
      No products found for <span class="font-medium">"{query}"</span>
    {:else}
      Start typing to search products
    {/if}
  </div>
{:else}
  <div class="space-y-1.5">
    {#each products as product (product.id)}
      <ProductCard {product} />
    {/each}
  </div>
  {#if products.length === 50}
    <p class="mt-2 text-center text-xs text-[var(--sidebar-text)] opacity-40">Showing first 50 results — refine your search</p>
  {/if}
{/if}
