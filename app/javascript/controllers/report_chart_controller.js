import { Controller } from "@hotwired/stimulus"
import { Chart, registerables } from "chart.js"

Chart.register(...registerables)

// Connects to data-controller="report-chart"
export default class extends Controller {
  static values = {
    data: Object,
    type: { type: String, default: "bar" }
  }

  connect() {
    this.renderChart()
  }

  disconnect() {
    if (this.chart) {
      this.chart.destroy()
      this.chart = null
    }
  }

  hasStackedDatasets() {
    if (!this.dataValue.datasets) return false
    return this.dataValue.datasets.some(dataset => dataset.stack !== undefined)
  }

  renderChart() {
    const ctx = this.element.getContext("2d")
    const isDark = document.documentElement.dataset.theme === "dark" ||
                   document.documentElement.dataset.theme === "dim"

    const gridColor = isDark ? "rgba(255, 255, 255, 0.1)" : "rgba(0, 0, 0, 0.1)"
    const textColor = isDark ? "rgba(255, 255, 255, 0.7)" : "rgba(0, 0, 0, 0.7)"

    this.chart = new Chart(ctx, {
      type: this.typeValue,
      data: this.dataValue,
      options: {
        responsive: true,
        maintainAspectRatio: false,
        plugins: {
          legend: {
            display: true,
            labels: { color: textColor, font: { size: 12 } }
          },
          tooltip: {
            backgroundColor: isDark ? "rgba(30, 30, 30, 0.95)" : "rgba(255, 255, 255, 0.95)",
            titleColor: isDark ? "#fff" : "#111",
            bodyColor: isDark ? "#ccc" : "#333",
            borderColor: isDark ? "rgba(255,255,255,0.1)" : "rgba(0,0,0,0.1)",
            borderWidth: 1,
            padding: 10,
            cornerRadius: 4
          }
        },
        scales: {
          x: {
            ticks: { color: textColor, font: { size: 11 }, maxRotation: 45 },
            grid: { color: gridColor },
            stacked: this.hasStackedDatasets()
          },
          y: {
            beginAtZero: true,
            ticks: { color: textColor, font: { size: 11 }, precision: 0 },
            grid: { color: gridColor },
            stacked: this.hasStackedDatasets()
          }
        }
      }
    })
  }
}
