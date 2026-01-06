import { Controller } from "@hotwired/stimulus"
import { buildSparklineChart, destroyChart } from "util/apex"

export default class extends Controller {
  static values = {
    id: String,
    downloads: Array,
  }

  static targets = ["chart"]

  connect() {
    const seriesData = this.downloadsValue.map((rollup) => {
      return {
        x: rollup[0],
        y: rollup[1],
      }
    })
    const series = [
      {
        name: "Downloads",
        data: seriesData,
      },
    ]

    const chart = buildSparklineChart(this.idValue, series, this.chartTarget)

    chart.render()
  }

  disconnect() {
    destroyChart(this.idValue)
  }
}
