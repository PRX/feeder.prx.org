import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["submit"]
  static values = { immediate: Boolean, debounce: Number }

  connect() {
    if (this.immediateValue) {
      this.submit()
    }
  }

  submit() {
    if (this.debounceValue) {
      clearTimeout(this.timer)
      this.timer = setTimeout(() => this.doClick(), this.debounceValue)
    } else {
      this.doClick()
    }
  }

  doClick() {
    if (this.hasSubmitTarget) {
      this.submitTarget.click()
    } else if (this.element) {
      this.element.click()
    }
  }
}
