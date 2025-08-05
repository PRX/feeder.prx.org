import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static outlets = ["apex-toggles"]
  static targets = ["start", "end", "main"]

  updateDates(event) {
    const [startDate, endDate] = JSON.parse(event.target.value)
    this.startTarget.value = startDate
    this.endTarget.value = endDate
  }

  changeMainCard(event) {
    this.mainTargets.forEach((el) => {
      if (el.dataset.chart.includes(event.params.chart)) {
        el.classList.remove("d-none")
      } else {
        el.classList.add("d-none")
      }
    })
  }

  toggleUI(event) {
    this.apexTogglesOutlet.toggleEpisodeUI(event)
  }
}
