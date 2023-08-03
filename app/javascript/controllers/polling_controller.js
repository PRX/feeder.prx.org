import { Controller } from "@hotwired/stimulus"

const DEFAULT_DEBOUNCE = 1000
const DEFAULT_MAX = 120

export default class extends Controller {
  static values = { debounce: Number, max: Number }

  connect() {
    this.count = 0
    this.frame = this.element.closest("turbo-frame")
    this.interval = setInterval(() => this.clickOrTurbo(), this.debounceValue || DEFAULT_DEBOUNCE)
  }

  disconnect() {
    clearInterval(this.interval)
  }

  // use a turbo-frame to reload if possible, to dodge document.click events
  clickOrTurbo() {
    this.count += 1
    if (this.count > (this.maxValue || DEFAULT_MAX)) {
      return this.disconnect()
    }

    if (this.frame && this.frame.src) {
      this.frame.reload()
    } else if (this.frame && this.element.href) {
      this.frame.src = this.element.href
    } else {
      this.element.click()
    }
  }
}
