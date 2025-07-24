import { Controller } from "@hotwired/stimulus"
import ApexCharts from "apexcharts"
import { DEFAULT_OPTIONS, LINE_DEFAULTS, mapColors, apexToggleSeries } from "util/apex"

export default class extends Controller {
  static values = {
    id: String,
    seriesData: Array,
  }

  static targets = ["chart"]

  connect() {
    const options = Object.assign({}, DEFAULT_OPTIONS)
    Object.assign(options.chart, {
      id: this.idValue,
      type: "line",
      height: "550px",
    })
    const typeOptions = Object.assign({}, LINE_DEFAULTS)
    Object.assign(typeOptions, {
      xaxis: {
        type: "numeric",
        tickAmount: 7,
        decimalsInFloat: 0,
        title: "Days Since Drop",
      },
      yaxis: {
        title: { text: "Downloads" },
      },
      colors: mapColors(this.seriesDataValue),
    })
    const series = this.buildSeries()
    Object.assign(options, series, typeOptions)

    const target = this.chartTarget
    const chart = new ApexCharts(target, options)
    chart.render()
  }

  buildSeries() {
    if (this.seriesDataValue.length) {
      return {
        series: this.seriesDataValue.map((d) => {
          return {
            name: d.ep.title,
            data: this.normalizeDropdayDownloads(d.rollups),
          }
        }),
      }
    }
  }

  normalizeDropdayDownloads(downloads) {
    const counts = downloads.map((d) => d.count)
    while (counts.length < 8) {
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

  toggleSeries(event) {
    apexToggleSeries(this.idValue, event.target.dataset.series)
  }
}
