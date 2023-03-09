import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["check", "field"]

  changeCheck() {
    this.checkTarget.parentElement.classList.add("d-none")
    this.fieldTarget.parentElement.classList.remove("d-none")
    this.fieldTarget.focus()
  }

  changeField() {
    if (!this.fieldTarget.value) {
      this.fieldTarget.value = ""
      this.fieldTarget.parentElement.classList.add("d-none")
      this.checkTarget.checked = false
      this.checkTarget.parentElement.classList.remove("d-none")
    }
  }

  displayOnlyThisField(event) {
    const field = event.target.value

    this.fieldTargets.forEach(el => {
      if (field !== el.getAttribute("field")) {
        el.classList.add("d-none")
        this.clearUntargetedFields(el)
      } else {
        el.classList.remove("d-none")
      }
    })
  }

  clearUntargetedFields(el) {
    const checks = Array.from(el.querySelectorAll(".form-check-input"))
    checks.forEach(check => {
      check.checked = false
    })
    const inputs = Array.from(el.querySelectorAll(".form-control"))
    inputs.forEach(input => {
      input.value = ""
    })
  }
}
