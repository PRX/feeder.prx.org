import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["datePreset", "startDate", "endDate", "interval", "uniques", "dropdays", "tab", "card", "mainCard"]

  static values = {
    mainCard: String,
    agentsCard: String,
  }

  connect() {
    this.setCurrentTab(this.tabTargets, "main", this.mainCardValue)
    this.displayCard(this.cardTargets, "main", this.mainCardValue)
  }

  updateDatePreset(event) {
    this.datePresetTarget.value = event.target.value
    this.datePresetTarget.dispatchEvent(new Event("change"))
  }

  setCurrentTab(tabs, cardValue, tabValue) {
    tabs.forEach((tab) => {
      if (tab.dataset.card === cardValue) {
        if (tab.dataset.tab === tabValue) {
          tab.ariaCurrent = true
          tab.classList.add("active")
        } else {
          tab.ariaCurrent = false
          tab.classList.remove("active")
        }
      }
    })
  }

  displayCard(cards, cardValue, tabValue) {
    cards.forEach((card) => {
      if (card.dataset.card.includes(cardValue)) {
        if (card.dataset.tab.includes(tabValue)) {
          card.classList.remove("d-none")
        } else {
          card.classList.add("d-none")
        }
      }
    })
  }

  changeTab(event) {
    const card = this[`${event.params.card}CardTarget`]
    card.value = event.params.tab
    card.dispatchEvent(new Event("change"))
  }
}
