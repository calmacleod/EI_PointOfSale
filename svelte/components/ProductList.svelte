<script>
  import ProductCard from "./ProductCard.svelte"

  let { products = [], query = "", topN = 0 } = $props()
</script>

{#if !query && products.length > 0}
  <p class="list-label">Top {topN} by sales</p>
{/if}

{#if products.length === 0}
  <div class="empty-state">
    <svg class="empty-icon" fill="none" stroke="currentColor" viewBox="0 0 24 24">
      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="1.5" d="M20 7l-8-4-8 4m16 0l-8 4m8-4v10l-8 4m0-10L4 7m8 4v10M4 7v10l8 4"/>
    </svg>
    <p class="empty-text">
      {#if query}
        No products found for <span class="empty-query">"{query}"</span>
      {:else}
        No products cached yet — sync to load data
      {/if}
    </p>
  </div>
{:else}
  <div class="card-list">
    {#each products as product (product.id)}
      <ProductCard {product} />
    {/each}
  </div>
  {#if products.length === 50}
    <p class="limit-note">Showing first 50 results — refine your search</p>
  {/if}
{/if}

<style>
  .list-label {
    margin: 0 0 8px;
    font-size: 11px;
    font-weight: 500;
    text-transform: uppercase;
    letter-spacing: 0.08em;
    color: #8e8e9a;
  }

  .empty-state {
    padding: 64px 0;
    text-align: center;
  }

  .empty-icon {
    display: block;
    margin: 0 auto 12px;
    width: 32px;
    height: 32px;
    color: #c8c8c8;
  }

  .empty-text {
    margin: 0;
    font-size: 14px;
    color: #6b6b6b;
  }

  .empty-query {
    font-weight: 500;
    color: #1a1a1a;
  }

  .card-list {
    display: flex;
    flex-direction: column;
    gap: 6px;
  }

  .limit-note {
    margin: 12px 0 0;
    text-align: center;
    font-size: 12px;
    color: #6b6b6b;
  }
</style>
