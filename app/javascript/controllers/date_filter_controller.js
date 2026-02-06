import { Controller } from "@hotwired/stimulus"
import flatpickr from "flatpickr"

export default class extends Controller {
  static targets = ["button", "label", "input"]
  static values = { all: String }

  connect() {
    this.previousValue = this.inputTarget.value || ""

    this.flat = flatpickr(this.buttonTarget, {
      dateFormat: "Y-m-d",
      defaultDate: this.previousValue,
      maxDate: "today",
      onChange: this.onChange.bind(this),
    })
  }

  onChange(_selected, value) {
    if (value === this.previousValue) {
      this.flat.clear()
    } else {
      this.labelTarget.innerHTML = value || this.allValue
      this.inputTarget.value = value
      this.inputTarget.dispatchEvent(new Event("change"))
      this.previousValue = value
    }
  }
}
