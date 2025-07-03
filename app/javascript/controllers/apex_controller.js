import { Controller } from "@hotwired/stimulus"
import ApexCharts from "apexcharts"

const DEFAULT_OPTIONS = {
  chart: {
    height: "100%",
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
  tooltip: {
    fixed: {
      enabled: true,
      position: "topRight",
    },
  },
  yaxis: {
    title: { text: "Downloads" },
  },
}

const LINE_DEFAULTS = {
  xaxis: { type: "datetime" },
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
    series: Array,
  }
  static targets = ["chart", "episodebox", "dateview"]

  connect() {
    const options = Object.assign({}, DEFAULT_OPTIONS)
    Object.assign(options.chart, {
      id: this.idValue,
      type: this.typeValue,
    })
    const series = {
      series: this.seriesValue,
    }
    const type_options = {}
    if (this.typeValue === "line") {
      Object.assign(type_options, LINE_DEFAULTS)
    } else if (this.typeValue === "bar") {
      Object.assign(type_options, BAR_DEFAULTS)
      Object.assign(options.chart, {
        height: "350px",
      })
    }
    Object.assign(options, series, type_options)

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
}
