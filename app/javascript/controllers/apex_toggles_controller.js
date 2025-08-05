import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static outlets = ["apex-downloads"]
  static targets = ["breakdown"]

  toggleSeriesForAll(event) {
    this.apexDownloadsOutlets.forEach((chart) => {
      chart.toggleSeries(event)
    })
  }

  changeBreakdown(event) {
    this.apexDownloadsOutlet.updateSeries(event)
  }

  toggleEpisodeUI(event) {
    this.breakdownTargets.forEach((target) => {
      if (event.params.breakdown === "totals") {
        target.classList.add("d-none")
      } else if (event.params.breakdown === "episodes") {
        target.classList.remove("d-none")
      }
    })
  }

  changeType(event) {
    this.apexDownloadsOutlet.updateOptions(event)
  }
}
