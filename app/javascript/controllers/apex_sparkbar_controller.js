import { Controller } from "@hotwired/stimulus"
import { buildDownloadsSeries, buildSparkbarChart, destroyChart } from "util/apex"

export default class extends Controller {
  static values = {
    id: String,
    downloads: Array,
  }

  static targets = ["chart"]

  connect() {
    const series = buildDownloadsSeries(this.downloadsValue)

    const chart = buildSparkbarChart(this.idValue, series, this.chartTarget)

    chart.render()
  }

  disconnect() {
    destroyChart(this.idValue)
  }
}
