import { Controller } from "@hotwired/stimulus"
import ApexCharts from "apexcharts"

export default class extends Controller {
  static targets = ["chart"]

  connect() {
    const options = {
      chart: {
        type: "line",
        height: "100%",
        width: "100%",
      },
      series: [
        {
          data: [23, 34, 12, 54, 32, 43],
        },
      ],
      xaxis: {
        categories: ["Jan", "Feb", "Mar", "Dec"],
      },
    }

    const chart = new ApexCharts(this.chartTarget, options)
    chart.render()
  }
}
