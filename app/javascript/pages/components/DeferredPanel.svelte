<script>
  import PanelHeader from "./PanelHeader.svelte"

  export let title = "Loading"
  export let message = "Fetching the latest data…"
</script>

<section class="p-region deferred-panel" aria-busy="true" aria-live="polite">
  <PanelHeader {title} count="Loading…" />
  <div class="p-body col" style="gap:var(--space-3)">
    <span class="faint">{message}</span>
    <div class="deferred-lines" aria-hidden="true">
      <span class="deferred-line"></span>
      <span class="deferred-line deferred-line-short"></span>
      <span class="deferred-line"></span>
    </div>
  </div>
</section>
