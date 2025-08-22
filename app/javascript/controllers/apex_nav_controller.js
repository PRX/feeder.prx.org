import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["start", "end", "mainStart", "mainEnd", "tab"]

  updateDates(event) {
    const [startDate, endDate] = JSON.parse(event.target.value)
    this.mainStartTarget.value = startDate
    this.mainEndTarget.value = endDate

    this.mainStartTarget.focus()
    this.mainStartTarget.blur()
    event.target.focus()
  }

  updateStartDate(event) {
    this.startTargets.forEach((target) => {
      target.addEventListener("change", function () {
        target.value = event.target.value
      })
      target.dispatchEvent(new Event("change"))
    })
  }

  updateEndDate(event) {
    this.endTargets.forEach((target) => {
      target.addEventListener("change", function () {
        target.value = event.target.value
      })
      target.dispatchEvent(new Event("change"))
    })
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
