import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
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
