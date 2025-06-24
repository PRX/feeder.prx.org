import { Controller } from "@hotwired/stimulus"
import ApexCharts from "apexcharts"

export default class extends Controller {
  static values = { series: Array, options: Object }
  static targets = ["chart"]

  connect() {
    const options = this.optionsValue

    const chart = new ApexCharts(this.chartTarget, options)
    chart.render()
  }
}
