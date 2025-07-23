import { Controller } from "@hotwired/stimulus"
import ApexCharts from "apexcharts"
import {
  DEFAULT_OPTIONS,
  LINE_DEFAULTS,
  alignDownloadsOnDateRange,
  setDateTimeLabel,
  apexToggleSeries,
} from "util/apex"

export default class extends Controller {
  static values = {
    id: String,
    seriesData: Array,
    dateRange: Array,
    interval: String,
  }

  static targets = ["chart", "episodebox"]

  connect() {
    const options = Object.assign({}, DEFAULT_OPTIONS)
    Object.assign(options.chart, {
      id: this.idValue,
      type: "line",
      height: "550px",
    })
    const series = this.buildSeries()
    const typeOptions = Object.assign({}, LINE_DEFAULTS)
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
        series: this.seriesDataValue.map((d) => {
          return {
            name: d.ep.title,
            data: alignDownloadsOnDateRange(d.rollups, this.dateRangeValue),
          }
        }),
      }
    } else {
      return []
    }
  }

  toggleSeries(event) {
    apexToggleSeries(this.idValue, event.target.dataset.series)
  }
}
