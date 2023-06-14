import { Controller } from "@hotwired/stimulus"

const DEFAULT_DEBOUNCE = 1000

export default class extends Controller {
  static values = { debounce: Number }

  connect() {
    this.frame = this.element.closest("turbo-frame")
    this.interval = setInterval(() => {
      this.clickOrTurbo()
    }, this.debounceValue || DEFAULT_DEBOUNCE)
  }

  disconnect() {
    clearInterval(this.interval)
  }

  // use a turbo-frame to reload if possible, to dodge document.click events
  clickOrTurbo() {
    if (this.frame && this.frame.src) {
      this.frame.reload()
    } else if (this.frame && this.element.href) {
      this.frame.src = this.element.href
    } else {
      this.element.click()
    }
  }
}
