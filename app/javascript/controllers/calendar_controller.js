import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["date"]

  connect() {
    if (this.dateTarget.getAttribute("disabled") !== "disabled") {
      this.element.classList.add("bg-primary", "text-light")
    }
  }

  toggleSelect(event) {
    if (!event.target.firstElementChild.getAttribute("disabled")) {
      event.target.classList.remove("bg-primary", "text-light")
      event.target.firstElementChild.setAttribute("disabled", true)
    } else {
      event.target.classList.add("bg-primary", "text-light")
      event.target.firstElementChild.removeAttribute("disabled")
    }
  }
}
