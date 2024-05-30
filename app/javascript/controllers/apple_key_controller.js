import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["key", "pem"]

  connect() {
  }

  convertKeyToB64() {
    let encoded = btoa(this.keyTarget.value)
    this.pemTarget.value = encoded
  }
}
