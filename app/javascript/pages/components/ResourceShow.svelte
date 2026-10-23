<script>
  import { Link, router } from "@inertiajs/svelte"
  import ConfirmModal from "./ConfirmModal.svelte"
  import PanelHeader from "./PanelHeader.svelte"
  import { displayValue, machineField } from "../../lib/design-system.js"

  export let details = []
  export let actions = {}
  let showRemove = false
  let showDeactivate = false

  function remove() { showRemove = false; router.delete(actions.delete) }
  function deactivate() { showDeactivate = false; router.patch(actions.deactivate, { user: { active: false } }) }
</script>

<section class="screen">
  <div class="p-split" style="grid-template-columns:minmax(0,2fr) minmax(240px,1fr)">
    <section class="p-region">
      <PanelHeader title="Record details" count={`${details.length} fields`} />
      <dl class="d-grid" style="grid-template-columns:repeat(2,minmax(0,1fr))">
        {#each details as detail}<div class="d-row"><dt>{detail.label}</dt><dd class:data={machineField(detail.label, detail.label)}>{displayValue(detail.value)}</dd></div>{/each}
      </dl>
    </section>
    <aside class="p-region">
      <PanelHeader title="Actions" />
      <div class="p-body col" style="gap:var(--space-2)">
        {#if actions.index}<Link href={actions.index} class="k-key">Back to list<span class="k-key-sub">All records</span></Link>{/if}
        {#if actions.edit}<Link href={actions.edit} class="k-key">Edit record<span class="k-key-sub">Command action</span></Link>{/if}
        {#if actions.history}<Link href={actions.history} class="k-key">Stock history<span class="k-key-sub">Receipts and stock movements</span></Link>{/if}
        {#if actions.deactivate}<button class="k-btn k-btn-danger" type="button" onclick={() => (showDeactivate = true)}>Deactivate account</button>{/if}
        {#if actions.delete}<button class="k-btn k-btn-danger" type="button" onclick={() => (showRemove = true)}>Remove record</button>{/if}
      </div>
    </aside>
  </div>
</section>

{#if showRemove}<ConfirmModal title="Remove this record?" message="This record will be removed from active use. This cannot be undone." confirmLabel="Remove record" danger oncancel={() => (showRemove = false)} onconfirm={remove} />{/if}
{#if showDeactivate}<ConfirmModal title="Deactivate this account?" message="This staff member will no longer be able to sign in. Their sales and audit history will be kept. You can reactivate the account by editing it." confirmLabel="Deactivate account" danger oncancel={() => (showDeactivate = false)} onconfirm={deactivate} />{/if}
