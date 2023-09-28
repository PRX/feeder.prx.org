import { Controller } from "@hotwired/stimulus"
import lookupFriendlyTimeZone from "util/lookupFriendlyTimeZone"

export default class extends Controller {
  connect() {
    const resolvedZone = Intl.DateTimeFormat().resolvedOptions().timeZone
    const zone = lookupFriendlyTimeZone(resolvedZone) || resolvedZone

    if (zone) {
      const values = [...this.element.options].map((o) => o.value)

      // add the zone if it's not in the options
      if (!values.includes(zone)) {
        const opt = document.createElement("option")
        opt.value = zone
        opt.text = zone
        this.element.appendChild(opt)
      }

      // make it look like this was the original value
      this.element.value = zone
      if (this.element.dataset.valueWas && this.element.dataset.valueWas !== "UTC") {
        this.element.dataset.valueWas = zone
      }

      // trigger changes
      this.element.dispatchEvent(new Event("change"))
    }
  }
}
