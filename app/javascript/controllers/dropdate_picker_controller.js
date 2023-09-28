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
        const date = new Date(this.inputTarget.value)
        this.setValueWas(this.dateTarget, date.toLocaleDateString())
        this.setValueWas(this.timeTarget, date.toLocaleTimeString())
      }
    }

    // listen for changes
    this.dateTarget.dataset.action = `${this.dateTarget.dataset.action} dropdate-picker#change`
    this.timeTarget.dataset.action = `${this.dateTarget.dataset.action} dropdate-picker#change`
    this.zoneTarget.dataset.action = `${this.dateTarget.dataset.action} dropdate-picker#change`
  }

  editing(event) {
    event.preventDefault()
    this.showingTargets.forEach((el) => el.classList.add("d-none"))
    this.editingTargets.forEach((el) => el.classList.remove("d-none"))
  }

  change() {
    if (this.dateTarget.value && isNaN(new Date(this.dateTarget.value))) {
      this.dateTarget.classList.add("is-invalid")
    } else {
      this.dateTarget.classList.remove("is-invalid")
    }

    if (this.timeTarget.value && isNaN(new Date(`2020-01-01 ${this.timeTarget.value}`))) {
      this.timeTarget.classList.add("is-invalid")
    } else {
      this.timeTarget.classList.remove("is-invalid")
    }

    // append the "friendly" zone value for rails to parse
    const fullUtcDate = new Date(`${this.dateTarget.value} ${this.timeTarget.value} UTC`)
    if (isNaN(fullUtcDate)) {
      this.inputTarget.value = ""
    } else {
      this.inputTarget.value = fullUtcDate.toISOString().replace("Z", " " + this.zoneTarget.value)
    }
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
