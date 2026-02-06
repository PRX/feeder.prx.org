import { Controller } from "@hotwired/stimulus"
import { buildSeries, buildChart, destroyChart } from "util/apex"

export default class extends Controller {
  static values = {
    id: String,
    downloads: Array,
    seriesType: String,
    chartType: String,
  }

  static targets = ["chart"]

  connect() {
    const series = buildSeries(this.seriesTypeValue, this.downloadsValue)
    const chart = buildChart(this.idValue, series, this.chartTarget, this.chartTypeValue)

    chart.render()
  }

  disconnect() {
    destroyChart(this.idValue)
  }
}
