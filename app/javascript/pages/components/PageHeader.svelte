<script>
  export let title = ""
  export let description = ""
</script>

<header class="mb-5 flex flex-col gap-3 sm:flex-row sm:items-end sm:justify-between">
  <div>
    <h1 class="text-2xl font-semibold tracking-tight">{title}</h1>
    {#if description}<p class="mt-1 max-w-3xl text-sm" style="color:var(--muted)">{description}</p>{/if}
  </div>
  <slot />
</header>
