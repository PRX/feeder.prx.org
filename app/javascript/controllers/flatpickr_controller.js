import { Controller } from "@hotwired/stimulus"
import flatpickr from "flatpickr"

const dateValidator = /^[0-9]{4}-[0-9]{2}-[0-9]{2}$/

export default class extends Controller {
  connect() {
    flatpickr(this.element, {
      allowInput: true,
      dateFormat: "Y-m-d",
      maxDate: this.element.max || null,
      minDate: this.element.min || null,
    })

    this.element.dataset.action = `${this.element.dataset.action} flatpickr#change`
  }

  change(event) {
    const val = this.element.value

    if (!val || (dateValidator.test(val) && !isNaN(new Date(val)))) {
      this.element.classList.remove("is-invalid")
    } else {
      this.element.classList.add("is-invalid")
      event.stopImmediatePropagation()
    }
  }
}
