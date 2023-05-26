import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["check", "field"]

  connect() {
    if (this.checkTarget.checked) {
      this.toggleDisplay()
    }
  }

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

    this.fieldTargets.forEach((el) => {
      if (field !== el.getAttribute("field")) {
        el.classList.add("d-none")
      } else {
        el.classList.remove("d-none")
      }
    })
  }

  toggleDisplay() {
    this.fieldTarget.classList.toggle("d-none")
  }
}
