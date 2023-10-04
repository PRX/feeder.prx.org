import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["link", "help"]

  static values = {
    help: Object,
  }

  updateHelp(event) {
    if (this.hasHelpValue && this.hasHelpTarget) {
      this.helpTarget.innerText = this.helpValue[event.target.value]
    }
  }
}
