import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["showPrivate", "showPublic"]

  togglePrivate(event) {
    if (event.target.checked) {
      this.show(this.showPrivateTargets)
      this.hide(this.showPublicTargets)
    } else {
      this.hide(this.showPrivateTargets)
      this.show(this.showPublicTargets)
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
