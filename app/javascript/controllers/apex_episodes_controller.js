import { Controller } from "@hotwired/stimulus"
import { buildDateTimeChart, buildDownloadsSeries, LINE_TYPE, destroyChart } from "util/apex"

export default class extends Controller {
  static values = {
    id: String,
    selectedEpisodes: Array,
    dateRange: Array,
    interval: String,
    options: String,
  }

  static targets = ["chart"]

  connect() {
    const series = buildDownloadsSeries(this.selectedEpisodesValue, this.dateRangeValue)
    const title = `Downloads by ${this.intervalValue.toLowerCase()}`
    const chart = buildDateTimeChart(this.idValue, series, this.chartTarget, LINE_TYPE, title)

    chart.render()
  }

  disconnect() {
    destroyChart(this.idValue)
  }
}
