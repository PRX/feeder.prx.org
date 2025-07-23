import { Controller } from "@hotwired/stimulus"
import ApexCharts from "apexcharts"
import { DEFAULT_OPTIONS, LINE_DEFAULTS, alignDownloadsOnDateRange, setDateTimeLabel } from "util/apex"

export default class extends Controller {
  static values = {
    id: String,
    seriesData: Array,
    dateRange: Array,
    interval: String,
  }

  static targets = ["chart"]

  connect() {
    const options = Object.assign({}, DEFAULT_OPTIONS)
    const series = this.buildSeries()

    const typeOptions = Object.assign({}, LINE_DEFAULTS)
    Object.assign(options.chart, {
      id: this.idValue,
      type: "line",
      height: "550px",
    })
    Object.assign(typeOptions, {
      xaxis: {
        type: "datetime",
        labels: {
          format: setDateTimeLabel(this.intervalValue),
        },
      },
      tooltip: {
        x: {
          format: setDateTimeLabel(this.intervalValue),
        },
      },
      yaxis: {
        title: { text: "Downloads" },
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
            data: alignDownloadsOnDateRange(this.seriesDataValue, this.dateRangeValue),
          },
        ],
      }
    } else {
      return []
    }
  }
}
