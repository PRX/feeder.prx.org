import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["date"]

  connect() {
    this.dateTargets.forEach((date) => {
      date.parentElement.addEventListener("click", this.toggleSelect)

      if (date.hasAttribute("selected")) {
        date.parentElement.setAttribute("selected", true)
        date.parentElement.classList.add("bg-primary", "text-light")
      }
    })
  }

  toggleSelect(event) {
    if (event.target.hasAttribute("selected")) {
      event.target.removeAttribute("selected")
      event.target.classList.remove("bg-primary", "text-light")
      event.target.firstElementChild.setAttribute("disabled", true)
    } else {
      event.target.setAttribute("selected", true)
      event.target.classList.add("bg-primary", "text-light")
      event.target.firstElementChild.removeAttribute("disabled")
    }
  }
}
