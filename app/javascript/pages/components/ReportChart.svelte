<script>
  import { onMount } from "svelte"
  export let data
  export let type = "bar"
  export let title = "Chart"
  let canvas
  let error = false

  onMount(() => {
    let chart
    let disposed = false
    import("chart.js/auto").then(({ default: Chart }) => {
      if (disposed) return
      const color = getComputedStyle(canvas).getPropertyValue("--color-text").trim() || "#666"
      const stacked = data.datasets.some((dataset) => dataset.stack)
      chart = new Chart(canvas, {
        type,
        data: { labels: [...data.labels], datasets: data.datasets.map((dataset) => ({ ...dataset, data: dataset.data.map(Number) })) },
        options: {
          responsive: true, maintainAspectRatio: false, animation: false,
          plugins: { legend: { labels: { color } } },
          scales: ["pie", "doughnut"].includes(type) ? {} : {
            x: { stacked, ticks: { color, maxTicksLimit: 12 } },
            y: { stacked, beginAtZero: true, ticks: { color } },
          },
        },
      })
    }).catch(() => (error = true))
    return () => { disposed = true; chart?.destroy() }
  })
</script>

<figure>
  <figcaption>{title}</figcaption>
  {#if error}<p>Chart unavailable. The report details and downloads are still available.</p>{:else}<div class="chart"><canvas bind:this={canvas} aria-label={`${title}: ${data.datasets.map((dataset) => dataset.label).join(", ")}. Values available in the chart data table below.`}></canvas></div>{/if}
  <details><summary>View chart data</summary><div class="chart-data"><table class="t"><thead><tr><th scope="col">Period / group</th>{#each data.datasets as dataset}<th scope="col">{dataset.label}</th>{/each}</tr></thead><tbody>{#each data.labels as label, index}<tr><th scope="row">{label}</th>{#each data.datasets as dataset}<td>{Number(dataset.data[index] || 0).toLocaleString(undefined, { maximumFractionDigits: 2 })}</td>{/each}</tr>{/each}</tbody></table></div></details>
</figure>

<style>
  figure { margin: 0; padding: var(--space-4); border-bottom: 1px solid var(--color-border); }
  figcaption { margin-bottom: var(--space-3); font-weight: 600; }
  .chart { height: 280px; position: relative; }
  details { margin-top: var(--space-3); font-size: var(--text-data); }
  summary { cursor: pointer; color: var(--color-text-muted); }
  .chart-data { overflow: auto; max-height: 320px; }
</style>
