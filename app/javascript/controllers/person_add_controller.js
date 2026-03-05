import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["table", "template"]

  add() {
    const now = Date.now()
    const row = this.templateTarget.innerHTML.replaceAll("__INDEX__", now)
    this.tableTarget.insertAdjacentHTML("beforeend", row)

    const buttons = this.tableTarget.querySelectorAll("[data-person-target=edit]")
    buttons[buttons.length - 1].click()
  }
}
