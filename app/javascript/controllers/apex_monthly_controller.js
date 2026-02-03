import { Controller } from "@hotwired/stimulus"
import { buildDateTimeChart, buildDownloadsSeries, BAR_TYPE, destroyChart } from "util/apex"

export default class extends Controller {
  static values = {
    id: String,
    downloads: Array,
    dateRange: Array,
  }

  static targets = ["chart"]

  connect() {
    const series = buildDownloadsSeries(this.downloadsValue, this.dateRangeValue)

    const chart = buildDateTimeChart(this.idValue, series, this.chartTarget, BAR_TYPE)
    // debugger

    chart.render()
  }

  disconnect() {
    destroyChart(this.idValue)
  }
}
