import { Controller } from "@hotwired/stimulus"
import {} from "util/apex"

export default class extends Controller {
  static values = {
    id: String,
    seriesData: Array,
    dateRange: Array,
  }

  static targets = ["chart"]

  connect() {}

  buildSeries() {
    if (this.seriesDataValue.length) {
      return {
        series: [
          {
            data: this.seriesDataValue,
          },
        ],
      }
    } else {
      return []
    }
  }
}
