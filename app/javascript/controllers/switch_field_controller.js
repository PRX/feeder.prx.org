import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["option", "field"]

  uncheckOtherOptions(matchingIndex) {
    this.optionTargets.forEach((opt, idx) => {
      if (matchingIndex !== idx) {
        opt.checked = false
      }
    })
  }

  displayOnlyThisField(matchingIndex) {
    this.fieldTargets.forEach((opt, idx) => {
      if (matchingIndex !== idx) {
        opt.classList.add("d-none")
      } else {
        opt.classList.remove("d-none")
      }
    })
  }

  changeOption(event) {
    this.uncheckOtherOptions(event.params["idx"])
    this.displayOnlyThisField(event.params["idx"])
  }
}
