import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static outlets = ["apex-toggles"]
  static targets = ["start", "end", "main", "breakdown"]

  updateDates(event) {
    const [startDate, endDate] = JSON.parse(event.target.value)
    this.startTarget.value = startDate
    this.endTarget.value = endDate
  }

  changeMainCard(event) {
    this.mainTargets.forEach((el) => {
      if (el.dataset.chart.includes(event.target.value)) {
        el.classList.remove("d-none")
      } else {
        el.classList.add("d-none")
      }
    })
  }

  changeBreakdown(event) {
    this.breakdownTargets.forEach((target) => {
      if (event.target.value === "totals") {
        target.classList.add("d-none")
      } else if (event.target.value === "episodes") {
        target.classList.remove("d-none")
      }
    })
  }
}
