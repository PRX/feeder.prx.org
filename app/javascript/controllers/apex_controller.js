import { Controller } from "@hotwired/stimulus"
import ApexCharts from "apexcharts"

const DEFAULT_OPTIONS = {
  chart: {
    width: "100%",
    zoom: { enabled: false },
    animations: {
      speed: 1000,
      animateGradually: {
        delay: 50,
      },
      dynamicAnimation: {
        enabled: true,
        speed: 1000,
      },
    },
  },
  yaxis: {
    title: { text: "Downloads" },
  },
}

const LINE_DEFAULTS = {
  xaxis: {
    type: "datetime",
  },
  stroke: {
    curve: "smooth",
    width: 2,
  },
  colors: [
    "#007EB2",
    "#FF9600",
    "#75BBE1",
    "#FFC107",
    "#6F42C1",
    "#DC3545",
    "#198754",
    "#D63384",
    "#20C997",
    "#555555",
  ],
  legend: {
    show: false,
  },
}

const BAR_DEFAULTS = {
  plotOptions: {
    bar: {
      horizontal: true,
    },
  },
}

export default class extends Controller {
  static values = {
    id: String,
    chartType: String,
    seriesType: String,
    seriesData: Array,
    dateRange: Array,
  }
  static targets = ["chart", "episodebox", "dateview", "datetrunc", "start"]

  connect() {
    if (this.seriesDataValue.length) {
      const options = Object.assign({}, DEFAULT_OPTIONS)
      const series = this.buildSeries()
      const typeOptions = this.setChartTypeDefaults(options, this.chartTypeValue, this.truncValue)

      Object.assign(options, series, typeOptions)

      const chart = new ApexCharts(this.chartTarget, options)
      chart.render()
    }
  }

  toggleSeries(event) {
    if (event.target.checked) {
      ApexCharts.exec(this.idValue, "showSeries", event.target.dataset.series)
    } else {
      ApexCharts.exec(this.idValue, "hideSeries", event.target.dataset.series)
    }
  }

  updateDateStart(event) {
    this.startTarget.value = event.target.value
  }

  buildSeries() {
    if (this.seriesTypeValue === "episodeRollups" && this.dateRangeValue.length) {
      return this.buildEpisodeRollupsSeries()
    } else if (this.seriesTypeValue === "agents") {
      return this.buildAgentSeries()
    }
  }

  buildEpisodeRollupsSeries() {
    if (this.seriesDataValue.length) {
      return {
        series: this.seriesDataValue.map((d) => {
          return {
            name: d.ep.title,
            data: this.alignRollupsOnDateRange(d.rollups, this.dateRangeValue),
          }
        }),
      }
    } else {
      return []
    }
  }

  buildAgentSeries() {
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

  alignRollupsOnDateRange(rollups, range) {
    return range.map((date) => {
      const utcDate = new Date(date).toUTCString()
      const rollup = rollups.filter((r) => {
        return new Date(r.hour).toUTCString() === utcDate
      })

      if (rollup[0]) {
        return {
          x: utcDate,
          y: rollup[0].count,
        }
      } else {
        return {
          x: utcDate,
          y: 0,
        }
      }
    })
  }

  updateTrunc(event) {
    this.datetruncTarget.value = event.target.value
  }

  // setDateTimeLabel(trunc) {
  //   // seemed to work at one point, but doesn't seem to work at the moment?
  //   if (trunc === "DAY") {
  //     return "MMM d"
  //   } else if (trunc === "MONTH") {
  //     return "MMMM d yyyy"
  //   } else if (trunc === "HOUR") {
  //     return "MMM d, h:mmtt"
  //   } else {
  //     return "MMM d"
  //   }
  // }

  setChartTypeDefaults(options, type, trunc) {
    if (type === "line") {
      Object.assign(options.chart, {
        id: this.idValue,
        type: type,
        height: "700px",
      })
      const typeOptions = Object.assign({}, LINE_DEFAULTS)
      // return Object.assign(typeOptions, {
      //   xaxis: {
      //     labels: {
      //       datetimeUTC: true,
      //       format: this.setDateTimeLabel(trunc),
      //     },
      //   },
      //   tooltip: {
      //     x: {
      //       format: this.setDateTimeLabel(trunc),
      //     },
      //   },
      // })
      return typeOptions
    } else if (type === "bar") {
      Object.assign(options.chart, {
        id: this.idValue,
        type: type,
        height: "350px",
      })
      const typeOptions = Object.assign({}, BAR_DEFAULTS)

      return Object.assign(typeOptions, {
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
    }
  }
}
