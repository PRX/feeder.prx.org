import { Controller } from "@hotwired/stimulus"
import { buildDateTimeChart, buildDownloadsSeries, LINE_TYPE, destroyChart } from "util/apex"

export default class extends Controller {
  static values = {
    id: String,
    rollups: Array,
    dateRange: Array,
    options: String,
  }

  static targets = ["chart"]

  connect() {
    const series = buildDownloadsSeries(this.rollupsValue, this.dateRangeValue)

    const chart = buildDateTimeChart(this.idValue, series, this.chartTarget, LINE_TYPE)

    chart.render()
  }

  disconnect() {
    destroyChart(this.idValue)
  }
}
