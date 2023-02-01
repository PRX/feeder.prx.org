import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["field"]

  focus() {
    this.fieldTarget.focus()
  }
}
