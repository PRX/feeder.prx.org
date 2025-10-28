import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["datePreset", "startDate", "endDate", "interval", "uniques", "dropdays", "tab", "card", "mainCard"]

  static values = {
    mainCard: String,
    agentsCard: String,
  }

  connect() {
    this.tabTargets.forEach((tab) => {
      if (tab.dataset.card === "main") {
        if (tab.dataset.tab === this.mainCardValue) {
          tab.click()
        }
      }
    })
  }

  updateDates(event) {
    const [startDate, endDate] = event.params.dates
    this.startDateTarget.value = startDate
    this.endDateTarget.value = endDate
    this.datePresetTarget.value = event.target.value

    this.startDateTarget.focus()
    this.startDateTarget.blur()
    this.endDateTarget.focus()
    this.endDateTarget.blur()
    event.target.focus()
  }

  updateDatePreset(event) {
    if (event.params.preset) {
      this.datePresetTarget.value = event.params.preset
    } else {
      this.datePresetTarget.value = event.target.value
    }
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
