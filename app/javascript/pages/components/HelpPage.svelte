<script>
  import { Link } from "@inertiajs/svelte"
  import BookOpen from "@lucide/svelte/icons/book-open"
  import Search from "@lucide/svelte/icons/search"
  import PanelHeader from "./PanelHeader.svelte"

  export let guides = []
  export let article = null
  export let actions = {}

  let query = ""
  let browseOpen = false

  $: terms = query.trim().toLocaleLowerCase().split(/\s+/).filter(Boolean)
  $: matches = guides.filter((guide) => terms.every((term) => guide.search_text.toLocaleLowerCase().includes(term)))
  $: categories = [...new Set(guides.map((guide) => guide.category))]
  $: related = guides.filter((guide) => article?.related?.includes(guide.slug))
  $: searching = terms.length > 0

  function keyboard(event) {
    if (event.key === "Escape" && query) { event.preventDefault(); query = "" }
  }
</script>

<section class="screen help-screen">
  <div class="help-layout">
    <aside class="p-region help-sidebar">
      <PanelHeader title="Help guide" count={guides.length}>
        <button class="k-btn k-btn-xs help-browse" type="button" aria-expanded={browseOpen} aria-controls="help-documents" onclick={() => (browseOpen = !browseOpen)}>Browse guides</button>
      </PanelHeader>
      <div class="p-body help-search">
        <label class="k-label" for="help-search">Search the guide</label>
        <div class="help-search-input"><Search size={16} /><input id="help-search" class="k-input" type="search" placeholder="Search tasks, features, behavior…" autocomplete="off" bind:value={query} onkeydown={keyboard} /></div>
        {#if searching}<p class="k-hint" role="status">{matches.length} {matches.length === 1 ? "document" : "documents"} found <button class="help-clear" type="button" onclick={() => (query = "")}>Clear search</button></p>{/if}
      </div>
      <nav id="help-documents" class="help-documents" class:is-open={browseOpen} aria-label="Help documents">
        <Link href={actions.index} class="help-document" aria-current={!article && !searching ? "page" : undefined}><BookOpen size={16} /><strong>All guides</strong></Link>
        {#each categories as category}
          {@const documents = matches.filter((guide) => guide.category === category)}
          {#if documents.length}
            <h2 class="p-title help-category">{category}</h2>
            {#each documents as guide (guide.slug)}
              <Link href={guide.path} class="help-document" aria-current={article?.slug === guide.slug && !searching ? "page" : undefined}>{guide.title}</Link>
            {/each}
          {/if}
        {/each}
      </nav>
    </aside>

    <div class="p-region help-content">
      {#if article && !searching}
        <article class="help-article" aria-labelledby="help-title">
          <header>
            <div class="help-tools"><Link href={actions.index} class="k-btn k-btn-sm k-btn-quiet">← All guides</Link><span class="push"></span>{#if actions.feature}<Link href={actions.feature} class="k-btn k-btn-sm k-btn-primary">Open this feature</Link>{/if}<button class="k-btn k-btn-sm" type="button" onclick={() => window.print()}>Print guide</button></div>
            <p class="help-eyebrow">{article.category}{article.audience === "admin" ? " · Administrators" : ""}</p>
            <h1 id="help-title">{article.title}</h1>
            <p class="help-summary">{article.summary}</p>
          </header>
          <nav class="help-toc" aria-label="On this page"><strong>On this page</strong>{#each article.sections as section}<a href={`#${section.id}`}>{section.title}</a>{/each}</nav>
          {#each article.sections as section (section.id)}
            <section id={section.id} class="help-section" aria-labelledby={`heading-${section.id}`}>
              <h2 id={`heading-${section.id}`}>{section.title}</h2>
              {#each section.paragraphs || [] as paragraph}<p>{paragraph}</p>{/each}
              {#if section.steps?.length}<ol>{#each section.steps as step}<li>{step}</li>{/each}</ol>{/if}
              {#if section.bullets?.length}<ul>{#each section.bullets as bullet}<li>{bullet}</li>{/each}</ul>{/if}
              {#if section.note}<aside class="help-note" role="note">{section.note}</aside>{/if}
            </section>
          {/each}
          {#if related.length}
            <footer class="help-related"><h2>Related guides</h2><div class="help-grid">{#each related as guide (guide.slug)}<Link href={guide.path} class="help-card"><strong>{guide.title}</strong><span>{guide.summary}</span></Link>{/each}</div></footer>
          {/if}
        </article>
      {:else}
        <div class="help-home">
          <p class="help-eyebrow">EI Point of Sale · Help guide</p>
          <h1>{searching ? "Search results" : "How can we help?"}</h1>
          <p class="help-summary">{searching ? `Documents matching “${query.trim()}”. Search covers the full guide text.` : "Learn the workflows, understand what each action does, and find the details you need while working."}</p>
          {#if !searching}<Link href={guides.find((guide) => guide.slug === "getting-started")?.path || actions.index} class="k-btn k-btn-primary help-start">Start with the basics →</Link>{/if}
          {#each categories as category}
            {@const documents = matches.filter((guide) => guide.category === category)}
            {#if documents.length}
              <section class="help-group" aria-label={category}>
                <h2>{category}</h2>
                <div class="help-grid">{#each documents as guide (guide.slug)}<Link href={guide.path} class="help-card"><strong>{guide.title}</strong><span>{guide.summary}</span></Link>{/each}</div>
              </section>
            {/if}
          {/each}
          {#if !matches.length}<div class="help-empty" role="status"><h2>No matching documents</h2><p>Try a shorter phrase, an item on the screen, or a term such as payment, refund, or stock.</p><button class="k-btn" type="button" onclick={() => (query = "")}>Show all guides</button></div>{/if}
        </div>
      {/if}
    </div>
  </div>
</section>

<style>
  .help-layout { display: grid; grid-template-columns: 260px minmax(0, 1fr); flex: 1; min-height: 0; }
  .help-sidebar { min-height: 0; }
  .help-search { display: grid; gap: var(--space-2); flex-shrink: 0; }
  .help-search-input { position: relative; }
  .help-search-input :global(svg) { position: absolute; left: var(--space-2); top: 50%; transform: translateY(-50%); color: var(--color-text-muted); pointer-events: none; }
  .help-search-input input { width: 100%; padding-left: calc(var(--space-6) + var(--space-1)); }
  .help-clear { color: var(--color-accent); background: none; border: 0; cursor: pointer; text-decoration: underline; }
  .help-documents { overflow-y: auto; min-height: 0; padding-bottom: var(--space-4); }
  .help-category { margin: var(--space-6) var(--space-3) var(--space-2); font-size: var(--text-label); }
  .help-documents :global(.help-document) { display: flex; align-items: center; gap: var(--space-2); padding: var(--space-2) var(--space-3); color: var(--color-text); text-decoration: none; border-left: 3px solid transparent; line-height: 1.5; }
  .help-documents :global(.help-document:hover) { background: var(--color-surface-alt); }
  .help-documents :global(.help-document[aria-current="page"]) { border-left-color: var(--color-accent); background: var(--color-accent-quiet); color: var(--color-accent); font-weight: 600; }
  .help-content { overflow-y: auto; display: block; }
  .help-article, .help-home { max-width: 1060px; margin: 0 auto; padding: var(--space-6) var(--space-6) calc(var(--space-6) * 2); }
  .help-article { max-width: 880px; }
  .help-eyebrow { color: var(--color-text-muted); font-size: var(--text-meta); text-transform: uppercase; letter-spacing: 0.08em; margin-bottom: var(--space-2); }
  h1 { font-size: var(--text-total); line-height: 1.2; margin: 0 0 var(--space-3); letter-spacing: -0.025em; }
  .help-summary { color: var(--color-text-muted); font-size: var(--text-strong); line-height: 1.7; max-width: 70ch; }
  .help-tools { display: flex; align-items: center; gap: var(--space-2); margin-bottom: var(--space-6); flex-wrap: wrap; }
  .help-toc { display: grid; gap: var(--space-2); margin: var(--space-6) 0; padding: var(--space-4); border: 1px solid var(--color-border); background: var(--color-surface-alt); }
  .help-toc a { color: var(--color-accent); }
  h2 { font-size: var(--text-readout); line-height: 1.4; margin-bottom: var(--space-3); }
  .help-section { margin-top: calc(var(--space-6) + var(--space-2)); scroll-margin-top: var(--space-4); font-size: var(--text-strong); line-height: 1.8; }
  .help-section p + p { margin-top: var(--space-3); }
  .help-section ul, .help-section ol { margin: var(--space-4) 0; padding-left: var(--space-6); }
  .help-section ul { list-style: disc; }
  .help-section ol { list-style: decimal; }
  .help-section li + li { margin-top: var(--space-2); }
  .help-note { margin-top: var(--space-4); padding: var(--space-3) var(--space-4); background: var(--color-surface-alt); border-left: 3px solid var(--color-accent); }
  .help-home :global(.help-start) { margin-top: var(--space-4); }
  .help-group, .help-related { margin-top: calc(var(--space-6) + var(--space-2)); }
  .help-related { border-top: 1px solid var(--color-border); padding-top: var(--space-6); }
  .help-grid { display: grid; grid-template-columns: repeat(2, minmax(0, 1fr)); gap: var(--space-3); }
  .help-grid :global(.help-card) { display: flex; flex-direction: column; gap: var(--space-2); padding: var(--space-4); border: 1px solid var(--color-border); border-radius: var(--radius-sm); color: var(--color-text); text-decoration: none; line-height: 1.6; }
  .help-grid :global(.help-card strong) { font-size: var(--text-strong); }
  .help-grid :global(.help-card span) { color: var(--color-text-muted); }
  .help-grid :global(.help-card:hover) { border-color: var(--color-accent); background: var(--color-accent-quiet); }
  .help-empty { margin-top: calc(var(--space-6) + var(--space-2)); }
  .help-empty p { color: var(--color-text-muted); margin-bottom: var(--space-4); }
  .help-browse { display: none; }
  @media (max-width: 800px) {
    .help-layout { grid-template-columns: minmax(0, 1fr); grid-template-rows: auto minmax(0, 1fr); }
    .help-sidebar { border-bottom: 1px solid var(--color-border); }
    .help-browse { display: inline-flex; }
    .help-documents { display: none; max-height: 220px; }
    .help-documents.is-open { display: block; }
    .help-article, .help-home { padding: var(--space-4); }
    .help-grid { grid-template-columns: minmax(0, 1fr); }
    h1 { font-size: var(--text-readout); }
  }
  @media print {
    .help-screen { color-scheme: light; --color-text: CanvasText; --color-text-muted: CanvasText; --color-surface: Canvas; --color-surface-alt: Canvas; --color-border: GrayText; --color-accent: LinkText; color: var(--color-text); background: var(--color-surface); }
    .help-sidebar, .help-tools, .help-toc, .help-related { display: none; }
    .help-layout, .help-content { display: block; overflow: visible; }
    .help-article { max-width: none; padding: 0; }
    .help-section { break-inside: avoid; }
  }
</style>
