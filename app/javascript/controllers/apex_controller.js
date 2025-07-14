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
}

const LINE_DEFAULTS = {
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
    interval: String,
  }
  static targets = ["chart", "episodebox", "dateview", "interval", "start", "main"]

  connect() {
    this.buildChart()
  }

  buildChart() {
    if (this.seriesDataValue.length) {
      const options = Object.assign({}, DEFAULT_OPTIONS)
      const series = this.buildSeries()
      const typeOptions = this.setChartTypeDefaults(options, this.seriesTypeValue)
      Object.assign(options, series, typeOptions)

      const target = this.chartTargets.filter((el) => {
        return el.dataset.chart === this.seriesTypeValue
      })[0]
      const chart = new ApexCharts(target, options)
      chart.render()
    }
  }

  updateDateStart(event) {
    this.startTarget.value = event.target.value
  }

  updateInterval(event) {
    this.intervalTarget.value = event.target.value
  }

  buildSeries() {
    if (this.seriesTypeValue === "episodeRollups" && this.dateRangeValue.length) {
      return this.buildEpisodeRollupsSeries()
    } else if (this.seriesTypeValue === "uniques") {
      return this.buildUniquesSeries()
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

  buildUniquesSeries() {
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

  toggleSeries(event) {
    if (event.target.checked) {
      ApexCharts.exec(this.idValue, "showSeries", event.target.dataset.series)
    } else {
      ApexCharts.exec(this.idValue, "hideSeries", event.target.dataset.series)
    }
  }

  changeMainCard(event) {
    this.mainTargets.forEach((el) => {
      if (el.dataset.chart === event.params.chart) {
        el.classList.remove("d-none")
      } else {
        el.classList.add("d-none")
      }
    })
  }

  setDateTimeLabel() {
    if (this.intervalValue === "MONTH") {
      return "MMMM yyyy"
    } else if (this.intervalValue === "HOUR") {
      return "MMM d, h:mmtt"
    } else {
      return "MMM d"
    }
  }

  setChartTypeDefaults(options, seriesType) {
    if (seriesType === "episodeRollups") {
      Object.assign(options.chart, {
        id: this.idValue,
        type: "line",
        height: "700px",
      })
      const typeOptions = Object.assign({}, LINE_DEFAULTS)
      Object.assign(typeOptions, {
        xaxis: {
          type: "datetime",
          labels: {
            format: this.setDateTimeLabel(),
          },
        },
        tooltip: {
          x: {
            format: this.setDateTimeLabel(),
          },
        },
        yaxis: {
          title: { text: "Downloads" },
        },
      })
      return typeOptions
    } else if (seriesType === "uniques") {
      Object.assign(options.chart, {
        id: this.idValue,
        type: "line",
        height: "700px",
      })
      const typeOptions = Object.assign({}, LINE_DEFAULTS)
      Object.assign(typeOptions, {
        xaxis: {
          type: "datetime",
          labels: {
            format: this.setDateTimeLabel(),
          },
        },
        tooltip: {
          x: {
            format: this.setDateTimeLabel(),
          },
        },
        yaxis: {
          title: { text: "Unique Listeners" },
        },
      })
      return typeOptions
    } else if (seriesType === "agents") {
      Object.assign(options.chart, {
        id: this.idValue,
        type: "bar",
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
