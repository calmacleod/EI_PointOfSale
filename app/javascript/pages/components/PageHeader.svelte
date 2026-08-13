<script>
  import PanelHeader from "./PanelHeader.svelte"
  export let title = ""
  export let description = ""
  export let count = null
</script>

<PanelHeader {title} {count}><slot /></PanelHeader>
{#if description}<p class="screen-description">{description}</p>{/if}
