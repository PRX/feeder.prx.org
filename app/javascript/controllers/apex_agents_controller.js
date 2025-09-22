import { Controller } from "@hotwired/stimulus"
import { buildDateTimeChart, alignDownloadsOnDateRange, LINE_TYPE } from "util/apex"

export default class extends Controller {
  static values = {
    id: String,
    agents: Array,
    dateRange: Array,
    interval: String,
    title: String,
  }

  static targets = ["chart"]

  connect() {
    const title = `Downloads by ${this.intervalValue.toLowerCase()}`
    const chart = buildDateTimeChart(this.idValue, this.buildAgentsSeries(), this.chartTarget, LINE_TYPE, title)

    chart.render()
  }

  buildAgentsSeries() {
    return this.agentsValue.map((agent) => {
      return {
        name: agent.label,
        data: alignDownloadsOnDateRange(agent.rollups, this.stripDateRange(), "day"),
        color: agent.color,
      }
    })
  }

  stripDateRange() {
    return this.dateRangeValue.map((date) => {
      return date.substring(0, 10)
    })
  }
}
