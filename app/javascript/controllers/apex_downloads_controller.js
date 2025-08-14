import { Controller } from "@hotwired/stimulus"
import { buildDateTimeChart, buildDownloadsSeries, dynamicBarAndAreaChart } from "util/apex"

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
    const chart = buildDateTimeChart(
      this.idValue,
      series,
      this.chartTarget,
      dynamicBarAndAreaChart(this.dateRangeValue)
    )

    chart.render()
  }
}
