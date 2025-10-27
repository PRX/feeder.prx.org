import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["startDate", "endDate", "interval", "uniques", "dropdays", "mainStart", "mainEnd", "tab", "card", "mainCard"]

  static values = {
    mainCard: String,
    agentsCard: String
  }

  connect() {
    this.tabTargets.forEach(tab => {
      if (tab.dataset.card === "main") {
        if (tab.dataset.tab === this.mainCardValue) {
          tab.click()
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
    this.updateSpecificTargets(this.intervalTargets, event.target.value, event.params.path)
  }

  updateUniques(event) {
    this.updateAllTargets(this.uniquesTargets, event.target.value)

    if (event.target.value === "calendar_week") {
      this.updateSpecificTargets(this.intervalTargets, "WEEK", event.params.path)
    } else if (event.target.value === "calendar_month") {
      this.updateSpecificTargets(this.intervalTargets, "MONTH", event.params.path)
    } else {
      this.updateSpecificTargets(this.intervalTargets, "DAY", event.params.path)
    }
  }

  updateDropdays(event) {
    this.updateAllTargets(this.dropdaysTargets, event.target.value)

    if ([7, 14, 28, 30, 60, 90].includes(parseInt(event.target.value))) {
      this.updateSpecificTargets(this.intervalTargets, "DAY", event.params.path)
    } else if ([24, 48, 72].includes(parseInt(event.target.value))) {
      this.updateSpecificTargets(this.intervalTargets, "HOUR", event.params.path)
    }
  }

  updateAllTargets(targets, value) {
    targets.forEach((target) => {
      target.addEventListener("change", function () {
        target.value = value
      })
      target.dispatchEvent(new Event("change"))
    })
  }

  updateSpecificTargets(targets, value, path) {
    targets.forEach((target) => {
      if (path === target.dataset.path) {
        target.addEventListener("change", function () {
          target.value = value
        })
        target.dispatchEvent(new Event("change"))
      }
    })
  }

  displayCard(event) {
    this.cardTargets.forEach((card) => {
      if (card.dataset.card.includes(event.params.card)) {
        if (card.dataset.tab.includes(event.params.tab)) {
          card.classList.remove("d-none")
        } else {
          card.classList.add("d-none")
        }
      }
    })

    this.mainCardTarget.value = event.params.tab
  }
}
