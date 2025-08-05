import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static outlets = ["apex-downloads"]

  toggleSeriesForAll(event) {
    this.apexDownloadsOutlets.forEach((chart) => {
      chart.toggleSeries(event)
    })
  }

  changeBreakdown(event) {
    this.apexDownloadsOutlet.changeBreakdown(event.target.value)
  }

  changeType(event) {
    const outlet = `apex${event.params.outlet}Outlet`
    this[outlet].changeType(event.params.type)
  }
}
