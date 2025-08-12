import { Controller } from "@hotwired/stimulus"
import ApexCharts from "apexcharts"
import { DEFAULT_OPTIONS, LINE_CHART, DATETIME_OPTIONS, alignDownloadsOnDateRange } from "util/apex"

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
    const options = this.buildOptions()
    const target = this.chartTarget

    const chart = new ApexCharts(target, options)
    chart.render()
  }

  buildOptions() {
    const options = Object.assign({}, DEFAULT_OPTIONS, DATETIME_OPTIONS, {
      series: this.buildSeries(),
      yaxis: {
        title: { text: "Downloads" },
      },
    })
    Object.assign(
      options.chart,
      {
        id: this.idValue,
        height: "550px",
      },
      LINE_CHART.chart
    )

    return options
  }

  buildSeries() {
    return this.selectedEpisodesValue.map((obj) => {
      return {
        name: obj.ep.title,
        data: alignDownloadsOnDateRange(obj.rollups, this.dateRangeValue),
        color: obj.color,
      }
    })
  }
}
