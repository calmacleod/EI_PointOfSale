<script>
  import { Link, router } from "@inertiajs/svelte"
  import PageHeader from "./PageHeader.svelte"
  export let title
  export let description
  export let details = []
  export let actions = {}
  function remove() { if (actions.delete && window.confirm("Remove this record?")) router.delete(actions.delete) }
</script>

<PageHeader {title} {description}><div class="flex gap-2">{#if actions.index}<Link href={actions.index} class="ui-button ui-button-secondary">Back</Link>{/if}{#if actions.edit}<Link href={actions.edit} class="ui-button ui-button-primary">Edit</Link>{/if}</div></PageHeader>
<section class="ui-card overflow-hidden"><dl class="grid sm:grid-cols-2 xl:grid-cols-3">{#each details as detail}<div class="border-b p-4 sm:border-r" style="border-color:var(--border)"><dt class="text-xs font-semibold uppercase tracking-wide" style="color:var(--muted)">{detail.label}</dt><dd class="mt-1 wrap-break-word text-sm">{typeof detail.value === "object" ? JSON.stringify(detail.value) : detail.value}</dd></div>{/each}</dl>{#if actions.delete}<footer class="flex justify-end border-t p-3" style="border-color:var(--border)"><button class="ui-button ui-button-danger" onclick={remove}>Remove</button></footer>{/if}</section>
