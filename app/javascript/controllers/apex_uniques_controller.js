import { Controller } from "@hotwired/stimulus"
import ApexCharts from "apexcharts"
import { buildDateTimeChart, dynamicBarAndAreaChart } from "util/apex"

export default class extends Controller {
  static values = {
    id: String,
    seriesData: Object,
    dateRange: Array,
    selection: String,
  }

  static targets = ["chart"]

  connect() {
    const series = this.buildSeries()
    const chart = buildDateTimeChart(
      this.idValue,
      series,
      this.chartTarget,
      dynamicBarAndAreaChart(this.dateRangeValue)
    )

    chart.render()
  }

  buildSeries() {
    return [
      {
        data: this.seriesDataValue.rollups.map((d) => {
          return {
            x: d["day"],
            y: d[this.selectionValue],
          }
        }),
        color: this.seriesDataValue.color,
      },
    ]
  }

  changeSeries(event) {
    const series = [
      {
        data: this.seriesDataValue.rollups.map((d) => {
          return {
            x: d["day"],
            y: d[event.target.value],
          }
        }),
        color: this.seriesDataValue.color,
      },
    ]

    ApexCharts.exec(this.idValue, "updateSeries", series)
  }
}
