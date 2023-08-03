import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["adBreaks", "button", "count", "counter", "label"]
  static values = { datesCount: Number }

  datesCountValueChanged() {
    this.recount()
  }

  setMedium(event) {
    if (event.target.value === "video") {
      this.adBreaksTarget.value = ""
      this.adBreaksTarget.disabled = true
    } else {
      this.adBreaksTarget.disabled = false
    }
    this.recount()
  }

  setAdBreaks(event) {
    this.recount()
  }

  recount() {
    const num = this.countSelectedTargets()

    // update label
    this.countTarget.innerHTML = num
    if (num === 1) {
      this.labelTarget.innerHTML = this.labelTarget.dataset.singular
    } else {
      this.labelTarget.innerHTML = this.labelTarget.dataset.plural
    }

    // enable button IF we have > 1 selected and a adBreak count
    if (num > 0 && (this.adBreaksTarget.disabled || parseInt(this.adBreaksTarget.value) >= 0)) {
      this.buttonTarget.disabled = false
    } else {
      this.buttonTarget.disabled = true
    }
  }

  countSelectedTargets() {
    const selectedTargets = this.counterTargets.filter((el) => {
      return !el.disabled
    })
    return selectedTargets.length
  }
}
