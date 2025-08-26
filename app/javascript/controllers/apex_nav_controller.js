import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["startDate", "endDate", "interval", "uniques", "mainStart", "mainEnd", "tab"]

  updateDates(event) {
    const [startDate, endDate] = JSON.parse(event.target.value)
    this.mainStartTarget.value = startDate
    this.mainEndTarget.value = endDate

    this.mainStartTarget.focus()
    this.mainStartTarget.blur()
    event.target.focus()
  }

  updateStartDate(event) {
    this.startDateTargets.forEach((target) => {
      target.addEventListener("change", function () {
        target.value = event.target.value
      })
      target.dispatchEvent(new Event("change"))
    })
  }

  updateEndDate(event) {
    this.endDateTargets.forEach((target) => {
      target.addEventListener("change", function () {
        target.value = event.target.value
      })
      target.dispatchEvent(new Event("change"))
    })
  }

  updateInterval(event) {
    this.intervalTargets.forEach((target) => {
      if (event.params.path === target.dataset.path) {
        target.addEventListener("change", function () {
          target.value = event.target.value
        })
        target.dispatchEvent(new Event("change"))
      }
    })
  }

  updateUniques(event) {
    this.uniquesTarget.value = event.target.value

    if (event.target.value === "calendar_week") {
      this.intervalTargets.forEach((target) => {
        if (event.params.path === target.dataset.path) {
          target.addEventListener("change", function () {
            target.value = "WEEK"
          })
          target.dispatchEvent(new Event("change"))
        }
      })
    } else if (event.target.value === "calendar_month") {
      this.intervalTargets.forEach((target) => {
        if (event.params.path === target.dataset.path) {
          target.addEventListener("change", function () {
            target.value = "MONTH"
          })
          target.dispatchEvent(new Event("change"))
        }
      })
    } else {
      this.intervalTargets.forEach((target) => {
        if (event.params.path === target.dataset.path) {
          target.addEventListener("change", function () {
            target.value = "DAY"
          })
          target.dispatchEvent(new Event("change"))
        }
      })
    }
    this.uniquesTarget.dispatchEvent(new Event("change"))
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
