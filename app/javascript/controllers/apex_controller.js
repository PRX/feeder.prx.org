import { Controller } from "@hotwired/stimulus"
import ApexCharts from "apexcharts"

export default class extends Controller {
  static values = {
    series: Object,
    options: Object,
    xaxis: String
  }
  static targets = ["chart"]

  connect() {
    const options = {
      chart: this.optionsValue,
      series: [this.seriesValue],
      xaxis: { type: this.xaxisValue },
      yaxis: {
        title: { text: "Downloads" },
      },
    }

    const chart = new ApexCharts(this.chartTarget, options)
    chart.render()
  }
}
