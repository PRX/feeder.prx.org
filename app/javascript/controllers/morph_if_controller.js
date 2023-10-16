import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  yes() {
    this.element.dataset.morph = true
  }

  no() {
    this.element.dataset.morph = false
  }
}
