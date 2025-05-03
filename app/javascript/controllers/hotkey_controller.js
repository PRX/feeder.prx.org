import { Controller } from "@hotwired/stimulus"

const DEFAULT_KEY = "/"
const FORM_ELEMENTS = ["INPUT", "TEXTAREA", "SELECT"]

export default class extends Controller {
  static values = { key: String }

  connect() {
    this.element.dataset.action = [this.element.dataset.action, "keydown@window->hotkey#keydown"]
      .filter((v) => v)
      .join(" ")
  }

  keydown(event) {
    const key = this.keyValue || DEFAULT_KEY
    if (event.key === key && !FORM_ELEMENTS.includes(event.target.tagName)) {
      this.element.click()
      event.preventDefault()
    }
  }
}
