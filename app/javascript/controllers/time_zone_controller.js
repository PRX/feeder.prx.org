import { Controller } from "@hotwired/stimulus"
import lookupFriendlyTimeZone from "util/lookupFriendlyTimeZone"

export default class extends Controller {
  connect() {
    const resolvedZone = Intl.DateTimeFormat().resolvedOptions().timeZone
    const friendlyZone = lookupFriendlyTimeZone(resolvedZone)

    if (friendlyZone || resolvedZone) {
      const values = [...this.element.options].map((o) => o.value)
      const hasResolved = values.includes(resolvedZone)
      const hasFriendly = values.includes(friendlyZone)

      // add the resolved zone if neither found
      if (hasFriendly) {
        this.setValue(friendlyZone)
      } else if (hasResolved) {
        this.setValue(resolvedZone)
      } else {
        this.addOption(resolvedZone)
        this.setValue(resolvedZone)
      }
    }
  }

  // make it look like this was the original value
  setValue(val) {
    this.element.value = val

    if (this.element.dataset.valueWas) {
      this.element.dataset.valueWas = val
    }

    this.element.dispatchEvent(new Event("change"))
  }

  addOption(val) {
    if (this.element.slim) {
      const data = this.element.slim.getData()
      this.element.slim.setData([{ text: val, value: val }, ...data])
    } else {
      const opt = document.createElement("option")
      opt.value = val
      opt.text = val
      this.element.insertBefore(opt, this.element.firstChild)
    }
  }
}
