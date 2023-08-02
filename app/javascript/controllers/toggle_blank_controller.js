import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["toggle"]

  toggleTargetConnected(el) {
    const action = el.dataset.action || ""
    el.dataset.action = `${action} change->toggle-blank#toggle`
  }

  toggle(event) {
    if (event.target.value) {
      for (const target of this.toggleTargets) {
        if (target !== event.target) {
          target.value = ""
          target.dispatchEvent(new Event("blur"))
        }
      }
    }
  }
}
