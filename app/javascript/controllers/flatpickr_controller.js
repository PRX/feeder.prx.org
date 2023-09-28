import { Controller } from "@hotwired/stimulus"
import flatpickr from "flatpickr"

export default class extends Controller {
  connect() {
    flatpickr(this.element, {
      allowInput: false,
      dateFormat: this.element.dataset.dateFormat || "Y-m-d",
      maxDate: this.element.max || null,
      minDate: this.element.min || null,
    })
  }
}
