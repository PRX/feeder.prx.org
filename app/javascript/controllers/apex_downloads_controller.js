import { Controller } from "@hotwired/stimulus"
import { buildDateTimeChart, buildDownloadsSeries, dynamicBarAndAreaType, destroyChart } from "util/apex"

export default class extends Controller {
  static values = {
    id: String,
    downloads: Object,
    dateRange: Array,
    interval: String,
  }

  static targets = ["chart"]

  connect() {
    const series = buildDownloadsSeries(this.downloadsValue, this.dateRangeValue)
    const title = `Downloads by ${this.intervalValue.toLowerCase()}`
    const chart = buildDateTimeChart(
      this.idValue,
      series,
      this.chartTarget,
      dynamicBarAndAreaType(this.dateRangeValue),
      title
    )

    chart.render()
  }

  disconnect() {
    destroyChart(this.idValue)
  }
}
