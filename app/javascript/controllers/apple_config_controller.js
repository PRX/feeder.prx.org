import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["showApple"]

  toggleConfig(event) {
    if (event.target.checked) {
      this.show(this.showAppleTargets)
    } else {
      this.hide(this.showAppleTargets)
    }
  }

  show(elements) {
    for (const el of elements) {
      el.classList.remove("d-none")
    }
  }

  hide(elements) {
    for (const el of elements) {
      el.classList.add("d-none")
    }
  }
}
