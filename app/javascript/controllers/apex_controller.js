import { Controller } from "@hotwired/stimulus"
import ApexCharts from "apexcharts"

export default class extends Controller {
  static values = {
    series: Array,
    options: Object,
  }
  static targets = ["chart"]

  connect() {
    const options = {
      chart: this.optionsValue,
      series: this.seriesValue,
      xaxis: { type: "datetime" },
      yaxis: {
        title: { text: "Downloads" },
      },
      stroke: {
        curve: "smooth",
        width: 2,
      },
      tooltip: {
        followCursor: true,
        fixed: {
          enabled: true,
          position: "topRight",
          offsetX: 250,
        },
      },
    }

    const chart = new ApexCharts(this.chartTarget, options)
    chart.render()
  }
}
