import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["counter", "display"]
  static values = {
    selected: { type: Number, default: 0 },
  }

  connect() {
    this.selectedValue = this.countSelectedTargets()
    this.displayTarget.innerHTML = this.selectedValue
  }

  recount() {
    this.selectedValue = this.countSelectedTargets()
    this.displayTarget.innerHTML = this.selectedValue
  }

  countSelectedTargets() {
    const selectedTargets = this.counterTargets.filter((el) => {
      return el.firstElementChild.disabled
    })
    return this.counterTargets.length - selectedTargets.length
  }
}
