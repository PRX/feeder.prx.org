import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    const now = new Date()
    const tz = now.toLocaleTimeString(undefined, { timeZoneName: "short" }).split(" ").pop()
    const offsetSeconds = now.getTimezoneOffset() * 60

    // change labels and values to local timezone
    for (const opt of this.element.options) {
      opt.text = opt.text.replace("UTC", tz)
      opt.value = parseInt(opt.value, 10) + offsetSeconds
    }
  }
}
