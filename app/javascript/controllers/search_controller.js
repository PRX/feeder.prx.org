import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["submit"]

  connect() {
    this.timeout = null
  }

  submit() {
    clearTimeout(this.timeout)
    this.timeout = setTimeout(() => {
      const next = this.encodeForm()
      if (next !== window.location.href) {
        this.submitForm()
        this.setHistory(next)
      }
    }, 200)
  }

  encodeForm() {
    const data = new FormData(this.element)
    const query = new URLSearchParams(data).toString()
    const clean = query
      .split("&")
      .filter((s) => s.split("=")[1])
      .join("&")
    return window.location.href.split("?")[0] + (clean ? `?${clean}` : "")
  }

  // NOTE: form.submit() doesn't seem to play well with Turbo at the moment -
  // so just click the hidden submit button
  submitForm() {
    this.submitTarget.click()
  }

  setHistory(next) {
    window.history.replaceState(window.history.state, null, next)
  }
}
