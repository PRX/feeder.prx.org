import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["date"]

  connect() {
    if (!this.isDisabled(this.dateTarget)) {
      if (this.isDraft(this.dateTarget)) {
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
    if (!this.isDisabled(event.target.firstElementChild)) {
      if (this.isDraft(event.target.firstElementChild)) {
        this.element.classList.remove("bg-danger")
      }
      event.target.classList.remove("bg-primary", "text-light")
      event.target.firstElementChild.setAttribute("disabled", true)
    } else {
      if (this.isDraft(event.target.firstElementChild)) {
        event.target.classList.add("bg-danger", "text-light")
      } else {
        event.target.classList.add("bg-primary", "text-light")
      }
      event.target.firstElementChild.removeAttribute("disabled")
    }
  }

  highlight(event) {
    event.target.classList.add("bg-secondary", "text-light")
    if (this.isDraft(event.target.firstElementChild)) {
      event.target.classList.remove("bg-warning", "bg-danger")
    }
  }

  unhighlight(event) {
    event.target.classList.remove("bg-secondary")

    if (this.isDraft(event.target.firstElementChild)) {
      if (this.isDisabled(event.target.firstElementChild)) {
        event.target.classList.add("bg-warning")
      } else {
        event.target.classList.add("bg-danger", "text-light")
      }
    }

    if (this.isDisabled(event.target.firstElementChild)) {
      event.target.classList.remove("text-light")
    }
  }

  isDisabled(el) {
    return el.getAttribute("disabled") === "true" || el.getAttribute("disabled") === "disabled"
  }

  isDraft(el) {
    return el.getAttribute("draft") === "true"
  }
}
