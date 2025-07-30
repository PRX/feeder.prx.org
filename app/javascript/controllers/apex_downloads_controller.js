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
    allOther: Object,
    selectedEpisodes: Array,
    dateRange: Array,
    interval: String,
  }

  static targets = ["chart", "episodebox"]

  connect() {
    const options = Object.assign({}, DEFAULT_OPTIONS)
    const series = this.buildSeries()

    const typeOptions = Object.assign({}, LINE_DEFAULTS)
    Object.assign(options.chart, {
      id: this.idValue,
      type: "area",
      stacked: true,
      height: "550px",
    })
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
    })
    Object.assign(options, series, typeOptions)

    const target = this.chartTarget
    const chart = new ApexCharts(target, options)
    chart.render()
  }

  buildSeries() {
    if (true) {
      const episodes = this.selectedEpisodesValue.map((d) => {
        return {
          name: d.ep.title,
          data: alignDownloadsOnDateRange(d.rollups, this.dateRangeValue),
          color: d.color,
        }
      })
      const others = {
        name: "All Other Episodes",
        data: alignDownloadsOnDateRange(this.allOtherValue.recent, this.dateRangeValue),
        color: this.allOtherValue.color,
      }
      episodes.unshift(others)
      return {
        series: episodes.reverse(),
      }
    }
  }

  toggleSeries(event) {
    apexToggleSeries(this.idValue, event.target.dataset.series)
  }
}
