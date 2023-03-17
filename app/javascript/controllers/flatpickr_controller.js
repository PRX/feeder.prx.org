import { Controller } from "@hotwired/stimulus"
import flatpickr from "flatpickr"

const invalidClass = "is-invalid"
const timeValidator = /^[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2}$/
const dateValidator = /^[0-9]{4}-[0-9]{2}-[0-9]{2}$/

export default class extends Controller {
  connect() {
    this.isTimestamp = !!this.element.dataset.timestamp
    this.dateFormat = this.isTimestamp ? "Y-m-d H:i:S" : "Y-m-d"
    this.validator = this.isTimestamp ? timeValidator : dateValidator

    this.picker = flatpickr(this.element, {
      allowInput: true,
      enableTime: false,
      dateFormat: this.dateFormat,
      disableMobile: true,
      parseDate: (str) => this.parseDate(str),
      formatDate: (date) => this.formatDate(date),
      onValueUpdate: () => this.validate(),
      minDate: this.element["min"],
      maxDate: this.element["max"],
    })
  }

  keydown(event) {
    if (event.key === "Enter") {
      this.picker.close()
    }
  }

  keyup(event) {
    this.validate()

    // if complete date string, select it. otherwise just jump to that month.
    const str = this.element.value
    const strictDate = this.parseDate(str, true)
    const fuzzyDate = this.parseDate(str, false)
    if (strictDate) {
      const newStr = this.formatDate(strictDate)
      const oldStr = this.formatDate(this.picker.selectedDates[0])
      if (newStr !== oldStr) {
        this.picker.setDate(strictDate)
      }
    } else if (fuzzyDate) {
      this.picker.jumpToDate(fuzzyDate)
    }
  }

  validate() {
    const str = this.element.value
    const date = this.parseDate(str, true)
    if (!str || date) {
      this.element.classList.remove(invalidClass)
      return true
    } else {
      this.element.classList.add(invalidClass)
      return false
    }
  }

  parseDate(str, strict = false) {
    if (Date.parse(str) && (!strict || this.validator.test(str))) {
      return flatpickr.parseDate(str, this.dateFormat)
    }
  }

  formatDate(date) {
    const str = flatpickr.formatDate(date, this.dateFormat)
    return str
  }
}
