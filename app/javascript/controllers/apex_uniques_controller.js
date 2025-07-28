import { Controller } from "@hotwired/stimulus"
import ApexCharts from "apexcharts"
import { DEFAULT_OPTIONS, LINE_DEFAULTS, setDateTimeLabel } from "util/apex"

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
      type: "line",
      height: "550px",
    })
    const typeOptions = Object.assign({}, LINE_DEFAULTS)
    Object.assign(typeOptions, {
      xaxis: {
        type: "datetime",
      },
      tooltip: {
        x: {
          format: setDateTimeLabel("DAY"),
        },
      },
      yaxis: {
        title: { text: "Unique Listeners" },
      },
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
        series: [
          {
            data: this.seriesDataValue.map((d) => {
              return {
                x: d["day"],
                y: d["last_7_rolling"],
              }
            }),
          },
        ],
      }
    }
  }
}
