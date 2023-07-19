import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["submit"]
  static values = { immediate: Boolean }

  connect() {
    if (this.immediateValue) {
      this.submit()
    }
  }

  submit() {
    if (this.hasSubmitTarget) {
      this.submitTarget.click()
    } else if (this.element) {
      this.element.click()
    }
  }
}
