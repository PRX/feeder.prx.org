import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["start", "end", "tab"]

  updateDates(event) {
    const [startDate, endDate] = JSON.parse(event.target.value)
    this.startTarget.value = startDate
    this.endTarget.value = endDate
  }

  changeTab(event) {
    this.tabTargets.forEach((el) => {
      if (el.dataset.tab.includes(event.params.tab)) {
        el.classList.remove("d-none")
      } else {
        el.classList.add("d-none")
      }
    })
  }
}
