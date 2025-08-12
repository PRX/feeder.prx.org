import { Controller } from "@hotwired/stimulus"
import ApexCharts from "apexcharts"

export default class extends Controller {
  toggleSeries(event) {
    ApexCharts.exec(event.params.id, "toggleSeries", event.params.series)
  }
}
