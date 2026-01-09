import { Controller } from "@hotwired/stimulus"
import { buildSparkbarChart, destroyChart } from "util/apex"

export default class extends Controller {
  static values = {
    id: String,
    downloads: Array,
  }

  static targets = ["chart"]

  connect() {
    const seriesData = this.downloadsValue
    const series = [
      {
        name: "Downloads",
        data: seriesData,
      },
    ]

    const chart = buildSparkbarChart(this.idValue, series, this.chartTarget)

    chart.render()
  }

  disconnect() {
    destroyChart(this.idValue)
  }
}
