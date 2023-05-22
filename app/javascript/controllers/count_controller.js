import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["counter", "display"]

  recount() {
    this.displayTarget.innerHTML = this.countSelectedTargets()
  }

  countSelectedTargets() {
    const selectedTargets = this.counterTargets.filter((el) => {
      return !el.disabled
    })
    return selectedTargets.length
  }
}
