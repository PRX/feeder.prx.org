import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    this.element.dataset.action = [this.element.dataset.action, "dropdown-select#select"].filter((v) => v).join(" ")
  }

  select() {
    const dropdown = this.element.closest(".dropdown")
    if (dropdown) {
      for (const el of dropdown.getElementsByClassName("dropdown-toggle")) {
        const icon = el.getElementsByClassName("material-icons")[0]?.outerHTML || ""
        el.innerHTML = icon + this.element.textContent
      }

      for (const el of dropdown.getElementsByClassName("dropdown-item")) {
        if (el === this.element) {
          el.classList.add("active")
        } else {
          el.classList.remove("active")
        }
      }
    }
  }
}
