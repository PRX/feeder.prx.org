import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "startDate",
    "endDate",
    "interval",
    "tab",
    "card",
    "mainCard",
    "agentsCard",
    "datePreset",
    "visiblePreset",
  ]

  static values = {
    mainCard: String,
    agentsCard: String,
  }

  connect() {
    this.tabTargets.forEach((el) => {
      if (el.dataset.card === "main") {
        if (el.dataset.tab === this.mainCardValue) {
          el.click()
        }
      } else if (el.dataset.card === "agents") {
        if (el.dataset.tab === this.agentsCardValue) {
          el.click()
        }
      }
    })
  }

  updateDates(event) {
    const [startDate, endDate] = event.params.dates
    const presetLabel = event.params.preset

    this.startDateTarget.value = startDate
    this.endDateTarget.value = endDate
    this.visiblePresetTarget.value = presetLabel
    this.datePresetTarget.value = event.target.value
    this.datePresetTarget.dispatchEvent(new Event("change"))
  }

  updateCustomPreset() {
    this.visiblePresetTarget.value = "Custom"
    this.datePresetTarget.value = "custom"
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

    this[`${event.params.card}CardTarget`].value = event.params.tab
  }
}
