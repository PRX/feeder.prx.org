import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["interval", "start", "main"]

  updateDateStart(event) {
    this.startTarget.value = event.target.value
  }

  updateInterval(event) {
    this.intervalTarget.value = event.target.value
  }

  changeMainCard(event) {
    this.mainTargets.forEach((el) => {
      if (el.dataset.chart === event.params.chart) {
        el.classList.remove("d-none")
      } else {
        el.classList.add("d-none")
      }
    })
  }
}
