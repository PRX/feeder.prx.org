import { Controller } from "@hotwired/stimulus"
import lookupFriendlyTimeZone from "util/lookupFriendlyTimeZone"

export default class extends Controller {
  static targets = ["input", "date", "time", "zone", "showing", "editing"]

  connect() {
    const resolvedZone = Intl.DateTimeFormat().resolvedOptions().timeZone
    const zone = lookupFriendlyTimeZone(resolvedZone) || resolvedZone

    // select zone and localize displayed date/time
    if (zone) {
      this.selectZone(zone)
      if (this.inputTarget.value) {
        const date = new Date(Date.parse(this.inputTarget.value))
        this.setValueWas(this.dateTarget, date.toLocaleDateString())
        this.setValueWas(this.timeTarget, date.toLocaleTimeString())
      }
    }
  }

  editing(event) {
    event.preventDefault()
    this.showingTargets.forEach((el) => el.classList.add("d-none"))
    this.editingTargets.forEach((el) => el.classList.remove("d-none"))
  }

  selectZone(zone) {
    const values = [...this.zoneTarget.options].map((o) => o.value)

    // add the zone if it's not in these friendly options
    if (!values.includes(zone)) {
      const opt = document.createElement("option")
      opt.value = zone
      opt.text = zone
      this.zoneTarget.appendChild(opt)
    }

    this.setValueWas(this.zoneTarget, zone)
  }

  setValueWas(field, value) {
    field.value = value
    field.dataset.valueWas = value
    field.dispatchEvent(new Event("change"))
  }
}
