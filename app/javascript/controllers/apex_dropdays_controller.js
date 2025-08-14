import { Controller } from "@hotwired/stimulus"
import { buildNumericChart, LINE_CHART } from "util/apex"

export default class extends Controller {
  static values = {
    id: String,
    seriesData: Array,
    range: Number,
  }

  static targets = ["chart"]

  connect() {
    const series = this.buildSeries()
    const chart = buildNumericChart(this.idValue, series, this.chartTarget, LINE_CHART)

    chart.render()
  }

  buildSeries() {
    if (this.seriesDataValue.length) {
      return this.seriesDataValue.map((d) => {
        return {
          name: d.episode.title,
          data: this.normalizeDropdayDownloads(d.rollups),
          color: d.color,
        }
      })
    }
  }

  normalizeDropdayDownloads(downloads) {
    const counts = downloads.map((d) => d.count)
    while (counts.length < this.rangeValue + 1) {
      counts.push(0)
    }
    return counts.map((c, i) => {
      const accumArr = counts.slice(0, i + 1)
      return {
        x: i,
        y: accumArr.reduce((sum, val) => sum + val, 0),
      }
    })
  }
}
