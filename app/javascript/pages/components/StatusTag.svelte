<script>
  import { stateTone } from "../../lib/design-system.js"

  export let value = ""
  export let tone = null
  export let solid = false

  $: resolvedTone = tone || stateTone(value)
</script>

<span class:s-tag-solid={solid} class={`s-tag s-${resolvedTone}`}><slot>{value || "—"}</slot></span>
