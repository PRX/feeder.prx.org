import { Controller } from "@hotwired/stimulus"
import flatpickr from "flatpickr"

const invalidClass = "is-invalid"
const timeValidator = /^[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9][0-9]?:[0-9]{2}:[0-9]{2} (AM|PM)( [A-Z]+)?$/
const dateValidator = /^[0-9]{4}-[0-9]{2}-[0-9]{2}$/
const defaultHour = 12

export default class extends Controller {
  connect() {
    this.isTimestamp = !!this.element.dataset.timestamp
    this.dateFormat = this.isTimestamp ? "Y-m-d h:i:S K" : "Y-m-d"
    this.validator = this.isTimestamp ? timeValidator : dateValidator

    // fix valueWas to match format (including timezone)
    if (this.element.dataset.valueWas) {
      const date = this.parseDate(this.element.dataset.valueWas)
      const formatted = this.formatDate(date)
      this.element.dataset.valueWas = formatted
    }

    // for timestamps, we need to make a hidden field for the actual ISO date
    if (this.isTimestamp) {
      const name = this.element.name
      this.element.removeAttribute("name")
      this.element.insertAdjacentHTML("afterend", `<input type="hidden" name="${name}">`)
      this.hiddenField = this.element.nextSibling
    }

    this.picker = flatpickr(this.element, {
      allowInput: true,
      enableTime: false,
      dateFormat: this.dateFormat,
      disableMobile: true,
      parseDate: (str) => this.parseDate(str),
      formatDate: (date) => this.formatDate(date),
      onChange: () => this.setDefaultHours(),
      onValueUpdate: () => this.validate(),
      onOpen: () => this.refreshValue(),
      onClose: () => this.refreshValue(),
      minDate: this.element.min,
      maxDate: this.element.max,
    })
  }

  setDefaultHours() {
    const date = this.picker.selectedDates[0]
    if (this.isTimestamp && date && date.getHours() !== defaultHour) {
      date.setHours(defaultHour)
      this.picker.setDate(date)
      this.hiddenField.value = date.toISOString()
    }
  }

  refreshValue() {
    const date = this.picker.selectedDates[0]

    // add/remove the timezone from the field as it opens/closes
    if (date) {
      this.element.value = this.formatDate(date)
    }

    // refresh hidden field for timestamps
    if (this.hiddenField) {
      this.hiddenField.value = date ? date.toISOString() : ""
    }
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
    const epoch = Date.parse(str)
    if (epoch && (!strict || this.validator.test(str))) {
      return new Date(epoch)
    }
  }

  formatDate(date) {
    const str = flatpickr.formatDate(date, this.dateFormat)

    if (this.picker && this.picker.isOpen) {
      return str
    } else {
      const tz = date.toLocaleTimeString(undefined, { timeZoneName: "short" }).split(" ").pop()
      return `${str} ${tz}`
    }
  }
}
