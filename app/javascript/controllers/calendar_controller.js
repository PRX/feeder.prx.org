import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["date"]

  connect() {
    if (this.dateTarget.getAttribute("disabled") !== "disabled") {
      if (this.dateTarget.getAttribute("draft") === "true") {
        this.element.classList.add("bg-danger", "text-light")
      } else {
        this.element.classList.add("bg-primary", "text-light")
      }
    }

    if (this.dateTarget.getAttribute("draft") === "true") {
      this.element.classList.add("bg-warning")
    }
  }

  toggleSelect(event) {
    if (!event.target.firstElementChild.getAttribute("disabled")) {
      if (event.target.firstElementChild.getAttribute("draft") === "true") {
        this.element.classList.remove("bg-danger")
      }
      event.target.classList.remove("bg-primary", "text-light")
      event.target.firstElementChild.setAttribute("disabled", true)
    } else {
      if (event.target.firstElementChild.getAttribute("draft") === "true") {
        event.target.classList.add("bg-danger", "text-light")
      } else {
        event.target.classList.add("bg-primary", "text-light")
      }
      event.target.firstElementChild.removeAttribute("disabled")
    }
  }
}
