import { Controller } from "@hotwired/stimulus"

const DEFAULT_DEBOUNCE = 1000

export default class extends Controller {
  static values = { debounce: Number }

  connect() {
    this.interval = setInterval(() => {
      this.element.click()
    }, this.debounceValue || DEFAULT_DEBOUNCE)
  }

  disconnect() {
    clearInterval(this.interval)
  }
}
