import { Controller } from "@hotwired/stimulus"
import { buildPieChart, buildDateTimeChart, alignDownloadsOnDateRange, LINE_TYPE, PIE_TYPE } from "util/apex"

export default class extends Controller {
  static values = {
    id: String,
    agents: Object,
    dateRange: Array,
    interval: String,
    title: String,
  }

  static targets = ["chart"]

  connect() {
    const chart = this.buildChart()

    chart.render()
  }

  buildChart() {
    if (this.hasDateRangeValue) {
      return buildDateTimeChart(this.idValue, this.buildAgentsSeries(), this.chartTarget, LINE_TYPE)
    } else {
      return buildPieChart(this.idValue, this.agentsValue.all, this.chartTarget, PIE_TYPE, this.titleValue)
    }
  }

  buildAgentsSeries() {
    return this.agentsValue.rollups.map((agent) => {
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
