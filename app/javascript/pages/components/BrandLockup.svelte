<script>
  export let variant = "mark"
  export let size = 26
  export let chrome = false
  export let mono = false
  export let label = "EI Point of Sale"

  $: markClass = `b-mark${chrome ? " b-mark--chrome" : ""}${mono ? " b-mark--mono" : ""}`
  $: lockupClass = `b-lockup${variant === "stacked" ? " b-lockup--stack" : ""}${chrome ? " b-lockup--chrome" : ""}`
</script>

{#if variant === "mark"}
  <span class={markClass} style={`--b-mark:${size}px`} role="img" aria-label={label}>
    <svg viewBox="0 0 32 32" aria-hidden="true">
      <path class="b-e" d="M3 5H21V9H7V14H18V18H7V23H21V27H3Z" fill="currentColor" />
      <path class="b-i" d="M25 5H29V27H25Z" fill="var(--brand-accent)" />
    </svg>
  </span>
{:else}
  <span class={lockupClass} style={`--b-mark:${size}px`} role="img" aria-label={label}>
    <span class={markClass} aria-hidden="true">
      <svg viewBox="0 0 32 32">
        <path class="b-e" d="M3 5H21V9H7V14H18V18H7V23H21V27H3Z" fill="currentColor" />
        <path class="b-i" d="M25 5H29V27H25Z" fill="var(--brand-accent)" />
      </svg>
    </span>
    {#if variant === "stacked"}
      <span class="b-text" aria-hidden="true"><span class="b-name">EI Retail</span><span class="b-sub">Point of Sale</span></span>
    {:else}
      <span class="b-sub" aria-hidden="true">Point of Sale</span>
    {/if}
  </span>
{/if}
