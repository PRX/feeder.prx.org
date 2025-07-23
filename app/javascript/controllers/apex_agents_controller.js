import { Controller } from "@hotwired/stimulus"
import ApexCharts from "apexcharts"
import { DEFAULT_OPTIONS, BAR_DEFAULTS } from "util/apex"

export default class extends Controller {
  static values = {
    id: String,
    seriesData: Array,
    dateRange: Array,
  }

  static targets = ["chart"]

  connect() {
    const options = Object.assign({}, DEFAULT_OPTIONS)
    Object.assign(options.chart, {
      id: this.idValue,
      type: "bar",
      height: "350px",
    })
    const typeOptions = Object.assign({}, BAR_DEFAULTS)
    const series = this.buildSeries()
    Object.assign(typeOptions, {
      tooltip: {
        y: {
          title: {
            formatter: function () {
              return ""
            },
          },
        },
      },
    })
    Object.assign(options, series, typeOptions)

    const target = this.chartTarget
    const chart = new ApexCharts(target, options)
    chart.render()
  }

  buildSeries() {
    if (this.seriesDataValue.length) {
      return {
        series: [
          {
            data: this.seriesDataValue,
          },
        ],
      }
    } else {
      return []
    }
  }
}
