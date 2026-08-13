<script>
  export let title = ""
  export let count = null
</script>

<div class="p-head">
  <h2 class="p-title">{title}</h2>
  {#if count !== null && count !== undefined}<span class="p-count">{count}</span>{/if}
  <div class="p-head-actions"><slot /></div>
</div>
