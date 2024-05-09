import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["field"]
  static values = { next: String }

  toggle() {
    const prev = this.fieldTarget.value
    this.fieldTarget.value = this.nextValue
    this.nextValue = prev
  }
}
