import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["preselected"]

  connect() {
    if (!this.isDisabled(this.preselectedTarget)) {
      if (this.isDraft(this.preselectedTarget)) {
        this.element.classList.add("bg-danger", "text-light")
      } else {
        this.element.classList.add("bg-primary", "text-light")
      }
    }

    if (this.preselectedTarget.getAttribute("draft") === "true") {
      this.element.classList.add("bg-warning")
    }
  }

  toggleSelect(event) {
    if (!this.isDisabled(event.target.firstElementChild)) {
      if (this.isDraft(event.target.firstElementChild)) {
        this.element.classList.remove("bg-danger")
      }
      event.target.classList.remove("bg-primary", "text-light")
      event.target.firstElementChild.disabled = true
    } else {
      if (this.isDraft(event.target.firstElementChild)) {
        event.target.classList.add("bg-danger", "text-light")
      } else {
        event.target.classList.add("bg-primary", "text-light")
      }
      event.target.firstElementChild.disabled = null
    }
  }

  isDisabled(el) {
    return el.disabled === true
  }

  isDraft(el) {
    return el.getAttribute("draft") === "true"
  }
}
