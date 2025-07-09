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
    type: String,
    dateStart: String,
    dateEnd: String,
    trunc: String,
    episodeRollups: Array,
  }
  static targets = ["chart", "episodebox", "dateview", "datetrunc"]

  connect() {
    const options = Object.assign({}, DEFAULT_OPTIONS)
    const series = this.buildEpisodeRollupsSeries()
    const typeOptions = this.setChartTypeDefaults(options, this.typeValue, this.truncValue)

    Object.assign(options, series, typeOptions)

    const chart = new ApexCharts(this.chartTarget, options)
    chart.render()
  }

  toggleSeries(event) {
    if (event.target.checked) {
      ApexCharts.exec(this.idValue, "showSeries", event.target.dataset.series)
    } else {
      ApexCharts.exec(this.idValue, "hideSeries", event.target.dataset.series)
    }
  }

  updateSeries(event) {
    ApexCharts.exec(this.idValue, "updateSeries", event.params.series)
    this.episodeboxTargets.forEach((target) => {
      if (target.checked) {
        ApexCharts.exec(this.idValue, "showSeries", target.dataset.series)
      } else {
        ApexCharts.exec(this.idValue, "hideSeries", target.dataset.series)
      }
    })
    this.dateviewTargets.forEach((el) => {
      if (el === event.target) {
        el.classList.add("active")
      } else {
        el.classList.remove("active")
      }
    })
  }

  resetSeries(event) {
    ApexCharts.exec(this.idValue, "updateSeries", event.params.series)
    this.episodeboxTargets.forEach((el) => {
      el.checked = true
      ApexCharts.exec(this.idValue, "showSeries", el.dataset.series)
    })
    this.dateviewTargets.forEach((el) => {
      el.classList.remove("active")
    })
  }

  buildEpisodeRollupsSeries() {
    if (this.episodeRollupsValue) {
      return {
        series: this.episodeRollupsValue.map((d) => {
          return {
            name: d.ep.title,
            data: this.alignRollupsOnDateRange(d.rollups, this.generateDateRange()),
          }
        }),
      }
    } else {
      return []
    }
  }

  generateDateRange() {
    if (this.dateStartValue && this.dateEndValue && this.truncValue) {
      const range = []
      if (this.truncValue === "MONTH") {
      } else if (this.truncValue === "DAY") {
        const start = new Date(this.dateStartValue)
        const end = new Date(this.dateEndValue)
        const startDay = new Date(Date.UTC(start.getFullYear(), start.getMonth(), start.getDate()))
        const endDay = new Date(Date.UTC(end.getFullYear(), end.getMonth(), end.getDate()))

        for (let time = startDay.getTime(); time <= endDay.getTime(); time += this.timestampInterval()) {
          range.push(new Date(time))
        }
      }

      return range
    } else {
      return []
    }
  }

  alignRollupsOnDateRange(rollups, range) {
    return range.map((date) => {
      const rollup = rollups.filter((r) => {
        return new Date(r.hour).toUTCString() === date.toUTCString()
      })

      if (rollup[0]) {
        return {
          x: date.toUTCString(),
          y: rollup[0].count,
        }
      } else {
        return {
          x: date.toUTCString(),
          y: 0,
        }
      }
    })
  }

  timestampInterval() {
    if (this.truncValue === "HOUR") {
      return 3600000
    } else if (this.truncValue === "WEEK") {
      return 604800000
    } else {
      // default to "DAY" interval
      return 86400000
    }
  }

  updateTrunc(event) {
    this.datetruncTarget.value = event.target.value
  }

  setDateTimeLabel(trunc) {
    // seemed to work at one point, but doesn't seem to work at the moment?
    if (trunc === "DAY") {
      return "MMM d"
    } else if (trunc === "MONTH") {
      return "MMMM d yyyy"
    } else if (trunc === "HOUR") {
      return "MMM d, h:mmtt"
    } else {
      return "MMM d"
    }
  }

  setChartTypeDefaults(options, type, trunc) {
    if (type === "line") {
      Object.assign(options.chart, {
        id: this.idValue,
        type: this.typeValue,
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
        type: this.typeValue,
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
