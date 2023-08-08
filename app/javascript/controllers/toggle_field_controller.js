import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["check", "field", "clear"]

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
      const types = el.getAttribute("field").split(" ")
      if (types.includes(field)) {
        el.classList.remove("d-none")
      } else {
        el.classList.add("d-none")
      }
    })
  }

  toggleDisplay() {
    this.fieldTarget.classList.toggle("d-none")
  }

  clearSelection() {
    const classes = Array.from(this.clearTarget.parentElement.classList)
    if (classes.includes("d-none")) {
      this.clearTarget.value = null
      this.clearTarget.dispatchEvent(new Event("change"))
    }
  }
}
