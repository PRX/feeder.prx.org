import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["submit"]

  preview() {
    this.submitTarget.click()
  }
}
