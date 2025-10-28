import { Controller } from "@hotwired/stimulus"
import { buildNumericChart, LINE_TYPE, destroyChart } from "util/apex"

export default class extends Controller {
  static values = {
    id: String,
    seriesData: Array,
    range: Number,
    interval: String,
  }

  static targets = ["chart"]

  connect() {
    const series = this.buildSeries()
    const title = `${this.intervalValue.toLowerCase()}s since episode drop`
    const chart = buildNumericChart(this.idValue, series, this.chartTarget, LINE_TYPE, title)

    chart.render()
  }

  disconnect() {
    destroyChart(this.idValue)
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
    while (counts.length < this.rangeValue) {
      counts.push(null)
    }
    return counts.map((c, i) => {
      const accumArr = counts.slice(0, i + 1)
      return {
        x: i + 1,
        y: this.accumulateDownloads(
          c,
          accumArr.reduce((sum, val) => sum + val, 0)
        ),
      }
    })
  }

  accumulateDownloads(val, reducer) {
    if (val === null) {
      return null
    } else {
      return reducer
    }
  }
}
