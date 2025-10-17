import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "startDate",
    "endDate",
    "interval",
    "uniquesInterval",
    "uniques",
    "dropdays",
    "mainStart",
    "mainEnd",
    "tab",
    "card",
    "mainCard"
  ]

  static values = {
    mainCard: String,
    agentsCard: String
  }

  connect() {
    this.tabTargets.forEach(el => {
      if (el.dataset.card === "main") {
        if (el.dataset.tab === this.mainCardValue) {
          el.classList.add("active")
          el.setAttribute("aria-selected", "true")
          el.click()
        }
      }
    })
  }

  updateDates(event) {
    const [startDate, endDate] = JSON.parse(event.target.value)
    this.mainStartTarget.value = startDate
    this.mainEndTarget.value = endDate

    this.mainStartTarget.focus()
    this.mainStartTarget.blur()
    this.mainEndTarget.focus()
    this.mainEndTarget.blur()
    event.target.focus()
  }

  updateStartDate(event) {
    this.updateAllTargets(this.startDateTargets, event.target.value)
  }

  updateEndDate(event) {
    this.updateAllTargets(this.endDateTargets, event.target.value)
  }

  updateInterval(event) {
    event.preventDefault()

    this.updateAllTargets(this.intervalTargets, event.target.value)
  }

  updateUniques(event) {
    this.uniquesTarget.value = event.target.value
    this.uniquesTarget.dispatchEvent(new Event("change"))
  }

  updateDropdays(event) {
    this.updateAllTargets(this.dropdaysTargets, event.target.value)

    // if ([7, 14, 28, 30, 60, 90].includes(parseInt(event.target.value))) {
    //   this.updateSpecificTargets(this.intervalTargets, "DAY", event.params.path)
    // } else if ([24, 48, 72].includes(parseInt(event.target.value))) {
    //   this.updateSpecificTargets(this.intervalTargets, "HOUR", event.params.path)
    // }
  }

  updateAllTargets(targets, value) {
    targets.forEach((target) => {
      target.value = value
      target.dispatchEvent(new Event("change"))
    })
  }

  updateSpecificTargets(targets, value, path) {
    targets.forEach((target) => {
      if (path === target.dataset.path) {
        target.value = value
        target.dispatchEvent(new Event("change"))
      }
    })
  }

  displayCard(event) {
    this.cardTargets.forEach((el) => {
      if (el.dataset.card.includes(event.params.card)) {
        if (el.dataset.tab.includes(event.params.tab)) {
          el.classList.remove("d-none")
        } else {
          el.classList.add("d-none")
        }
      }
    })

    this.mainCardTarget.value = event.params.tab
  }
}
