import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["check", "field"]

  changeCheck() {
    this.checkTarget.parentElement.classList.add("d-none")
    this.fieldTarget.parentElement.classList.remove("d-none")
    this.fieldTarget.focus()
  }

  changeField() {
    if (!this.fieldTarget.value || this.fieldTarget.value != " ") {
      this.fieldTarget.value = ""
      this.fieldTarget.parentElement.classList.add("d-none")
      this.checkTarget.checked = false
      this.checkTarget.parentElement.classList.remove("d-none")
    }
  }
}
