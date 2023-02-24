import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["submit"]

  connect() {
    this.timeout = null
  }

  submit() {
    clearTimeout(this.timeout)
    this.timeout = setTimeout(() => {
      this.submitForm()
    }, 200)
  }

  // NOTE: form.submit() doesn't seem to play well with Turbo at the moment -
  // so just click the hidden submit button
  submitForm() {
    this.submitTarget.click()
  }
}
