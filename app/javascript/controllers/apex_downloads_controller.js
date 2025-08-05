import { Controller } from "@hotwired/stimulus"
import ApexCharts from "apexcharts"
import {
  DEFAULT_OPTIONS,
  BAR_CHART,
  AREA_CHART,
  LINE_CHART,
  DATETIME_OPTIONS,
  alignDownloadsOnDateRange,
  updateOptions,
  updateSeries,
} from "util/apex"

export default class extends Controller {
  static values = {
    id: String,
    totalRecent: Array,
    allOther: Object,
    selectedEpisodes: Array,
    dateRange: Array,
    interval: String,
    options: String,
  }

  static targets = ["chart", "episodebox"]

  connect() {
    const options = this.buildOptions()
    const target = this.chartTarget

    const chart = new ApexCharts(target, options)
    chart.render()
  }

  buildOptions() {
    const options = Object.assign({}, DEFAULT_OPTIONS, DATETIME_OPTIONS, {
      series: this.buildStackedSeries(),
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
      AREA_CHART.chart
    )
    Object.assign(options.tooltip, {
      inverseOrder: true,
    })
    return options
  }

  buildTotalSeries() {
    return [
      {
        name: "All Episodes",
        data: alignDownloadsOnDateRange(this.totalRecentValue, this.dateRangeValue),
      },
    ]
  }

  buildStackedSeries() {
    if (this.selectedEpisodesValue && this.allOtherValue.recent) {
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
      return episodes.reverse()
    }
  }

  changeType(type) {
    const options = {}

    if (type === "bar") {
      Object.assign(options, BAR_CHART)
    } else if (type === "area") {
      Object.assign(options, AREA_CHART)
    } else if (type === "line") {
      Object.assign(options, LINE_CHART)
    }

    updateOptions(this.idValue, options)
  }

  changeBreakdown(breakdown) {
    if (breakdown === "totals") {
      updateSeries(this.idValue, this.buildTotalSeries())
    } else if (breakdown === "episodes") {
      updateSeries(this.idValue, this.buildStackedSeries())
    }
  }

  toggleSeries(event) {
    ApexCharts.exec(this.idValue, "toggleSeries", event.params.series)
  }
}
