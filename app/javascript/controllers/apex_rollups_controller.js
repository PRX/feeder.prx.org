import { Controller } from "@hotwired/stimulus"
import ApexCharts from "apexcharts"
import {
  DEFAULT_OPTIONS,
  LINE_DEFAULTS,
  alignDownloadsOnDateRange,
  mapColors,
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
    const series = this.buildSeries()
    Object.assign(options.chart, {
      id: this.idValue,
      type: "area",
      stacked: true,
      height: "550px",
    })
    const typeOptions = Object.assign({}, LINE_DEFAULTS)
    Object.assign(typeOptions, {
      xaxis: {
        type: "datetime",
      },
      tooltip: {
        x: {
          format: setDateTimeLabel(this.intervalValue),
        },
        inverseOrder: true,
      },
      yaxis: {
        title: { text: "Downloads" },
      },
      dataLabels: {
        enabled: false,
      },
      colors: mapColors(this.seriesDataValue).slice().reverse(),
    })

    Object.assign(options, series, typeOptions)
    const target = this.chartTarget

    const chart = new ApexCharts(target, options)
    chart.render()
  }

  buildSeries() {
    if (this.seriesDataValue.length) {
      return {
        series: this.seriesDataValue
          .map((d) => {
            return {
              name: d.ep.title,
              data: alignDownloadsOnDateRange(d.rollups, this.dateRangeValue),
            }
          })
          .reverse(),
      }
    } else {
      return []
    }
  }

  toggleSeries(event) {
    apexToggleSeries(this.idValue, event.target.dataset.series)
  }
}
