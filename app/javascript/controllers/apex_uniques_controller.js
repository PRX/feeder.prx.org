import { Controller } from "@hotwired/stimulus"
import ApexCharts from "apexcharts"
import { buildDateTimeChart, dynamicBarAndAreaType, destroyChart } from "util/apex"

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
    const title = "Unique Listeners"
    const chart = buildDateTimeChart(
      this.idValue,
      series,
      this.chartTarget,
      dynamicBarAndAreaType(this.dateRangeValue),
      title
    )

    chart.render()
  }

  disconnect() {
    destroyChart(this.idValue)
  }

  buildSeries() {
    return [
      {
        name: "Unique Listeners",
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
        name: "Unique Listeners",
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
