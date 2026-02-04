import { Controller } from "@hotwired/stimulus"
import { buildEpisodesChart, buildMultipleEpisodeDownloadsSeries, destroyChart } from "util/apex"

export default class extends Controller {
  static values = {
    id: String,
    rollups: Array,
  }

  static targets = ["chart"]

  connect() {
    const series = buildMultipleEpisodeDownloadsSeries(this.rollupsValue)

    const chart = buildEpisodesChart(this.idValue, series, this.chartTarget)

    chart.render()
  }

  disconnect() {
    destroyChart(this.idValue)
  }
}
