import { Controller } from "@hotwired/stimulus"
import flatpickr from "flatpickr"

export default class extends Controller {
  static targets = ["input", "date", "time", "zone", "showing", "editing"]

  connect() {
    // localize inputs
    if (this.inputTarget.value) {
      const date = new Date(this.inputTarget.value)
      this.setValue(this.dateTarget, date.toLocaleDateString(), true)
      this.setValue(this.timeTarget, date.toLocaleTimeString(), true)
    }

    // listen for changes
    this.dateTarget.dataset.action = `${this.dateTarget.dataset.action} dropdate-picker#change dropdate-picker#defaultTime`
    this.timeTarget.dataset.action = `${this.timeTarget.dataset.action} dropdate-picker#change`
    this.zoneTarget.dataset.action = `${this.zoneTarget.dataset.action} dropdate-picker#change`

    // init flatpickr
    flatpickr(this.dateTarget, {
      allowInput: true,
      dateFormat: "n/j/Y",
    })
    flatpickr(this.timeTarget, {
      allowInput: true,
      dateFormat: "h:i:S K",
      enableTime: true,
      enableSeconds: true,
      noCalendar: true,
    })
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

    if (this.timeTarget.value && isNaN(new Date(`2020/01/01 ${this.timeTarget.value}`))) {
      this.timeTarget.classList.add("is-invalid")
    } else {
      this.timeTarget.classList.remove("is-invalid")
    }

    // set released_at field to datetime without zone
    const fullUtcDate = new Date(`${this.dateTarget.value} ${this.timeTarget.value} UTC`)
    if (isNaN(fullUtcDate)) {
      this.inputTarget.value = ""
    } else {
      this.inputTarget.value = fullUtcDate.toISOString().replace("Z", "")
    }
  }

  defaultTime() {
    if (this.dateTarget.value && !this.timeTarget.value) {
      this.setValue(this.timeTarget, "12:00:00 PM")
      this.timeTarget.classList.remove("form-control-blank")
      this.change()
    } else if (!this.dateTarget.value && this.timeTarget.value) {
      this.setValue(this.timeTarget, "")
      this.timeTarget.classList.add("form-control-blank")
      this.change()
    }
  }

  setValue(field, value, setValueWas = false) {
    field.value = value
    if (setValueWas) {
      field.dataset.valueWas = value
    }
    field.dispatchEvent(new Event("change"))
  }
}
